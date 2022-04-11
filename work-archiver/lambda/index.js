const _archiver = require("archiver");
const AWS = require("aws-sdk");
const axios = require("axios");
const elasticsearch = require("elasticsearch");
const path = require("path");
const request = require("request");
const uuid = require("node-uuid");

const bucket = process.env.archiveBucket;
const elasticsearchEndpoint = process.env.elasticsearchEndpoint;
const region = process.env.region;
const index = process.env.indexName;
const senderEmail = process.env.senderEmail;
const defaultWidth = 1000;
const maxWidthAllowed = 10001;

const streamTo = (key) => {
  const stream = require("stream");
  const pass = new stream.PassThrough();
  const s3 = new AWS.S3();
  s3.upload({
    Bucket: bucket,
    Key: key,
    Body: pass,
    ContentType: "application/zip",
  })
    .on("httpUploadProgress", (progress) => {
      console.log("progress", progress);
    })
    .send((err, data) => {
      if (err) {
        pass.destroy(err);
      } else {
        console.log(`File written to:  ${data.Location}`);
        pass.destroy();
      }
    });
  return pass;
};

async function makeRequest(workId) {
  return new Promise((resolve, _reject) => {
    const endpoint = new AWS.Endpoint(elasticsearchEndpoint);
    const request = new AWS.HttpRequest(endpoint, region);

    const document = {
      _source: ["accessionNumber", "representativeImageUrl"],
      size: 2000,
      query: {
        bool: {
          must: [
            { match: { "model.name.keyword": "FileSet" } },
            { match: { "workId.keyword": workId } },
          ],
        },
      },
    };

    request.method = "POST";
    request.path += index + "/_search";
    request.body = JSON.stringify(document);
    request.headers["host"] = elasticsearchEndpoint;
    request.headers["Content-Type"] = "application/json";
    request.headers["Content-Length"] = Buffer.byteLength(request.body);

    let chain = new AWS.CredentialProviderChain();
    chain.resolve((err, credentials) => {
      if (err) {
        console.error("Returning unsigned request: ", err);
      } else {
        var signer = new AWS.Signers.V4(request, "es");
        signer.addAuthorization(credentials, new Date());
      }
      resolve(request);
    });
  });
}

async function awsFetch(request) {
  return new Promise((resolve, reject) => {
    var client = new AWS.HttpClient();
    client.handleRequest(
      request,
      null,
      function (response) {
        let responseBody = "";
        response.on("data", function (chunk) {
          responseBody += chunk;
        });
        response.on("end", function (chunk) {
          resolve(responseBody);
        });
      },
      function (error) {
        console.error("Error: " + error);
      }
    );
  });
}

async function imageUrls(workId) {
  let request = await makeRequest(workId);
  let response = await awsFetch(request);

  let doc = JSON.parse(response);

  console.log("response: ", response);

  const urls = [];
  doc.hits.hits.map((hit) => {
    if (
      hit._source.representativeImageUrl != null &&
      hit._source.accessionNumber != null
    ) {
      urls.push({
        label: hit._source.accessionNumber,
        url: hit._source.representativeImageUrl,
      });
    }
  });

  return urls;
}

async function processEvent(event, callback) {
  console.log("event: ", event);

  const workId = event.queryStringParameters.workId;
  const email = event.queryStringParameters.email;
  const width = event.queryStringParameters.width
    ? event.queryStringParameters.width
    : defaultWidth;
  const referer = event.headers.Referer || event.headers.referer;

  console.log(`Creating zip for workId: ${workId}`);
  console.log(`email: ${email}`);
  console.log(`width: ${width}`);
  console.log("referer: ", referer);

  if (workId == null || email == null || !email.endsWith("@northwestern.edu")) {
    const message =
      "Work id or email not provided, or non northwestern email address was provided.";
    console.error(message);
    throw new Error(message);
  }

  let iiifSize;
  if (width == "full") {
    iiifSize = "max";
  } else if (width > 0 && width < maxWidthAllowed) {
    iiifSize = `${width},`;
  } else {
    const message = "Invalid width requested.";
    console.error(message);
    throw new Error(message);
  }

  const key = path.join("temp", `${uuid.v4()}.zip`);
  const images = await imageUrls(workId);
  console.log("images: ", images);

  if (images.length > 0) {
    await new Promise((_resolve, reject) => {
      const uploadStream = streamTo(key);
      const archive = _archiver("zip", {
        zlib: { level: 9 },
      });
      archive.on("error", function (err) {
        throw err;
      });

      uploadStream.on("close", function () {
        console.log(archive.pointer() + " total bytes");
        console.log(
          "Archiver has been finalized and the output file descriptor has closed."
        );
      });
      uploadStream.on("end", function () {
        console.log("Data has been drained");
        const downloadKey = downloadLink(key);
        console.log("downloadKey: ", downloadKey);
        sendEmail(email, downloadKey, referer);
        callback(null, {
          statusCode: 200,
          body: JSON.stringify({ final_destination: downloadKey }),
        });
      });
      uploadStream.on("error", function (err) {
        reject(err);
      });

      archive.pipe(uploadStream);
      images.forEach((image) => {
        const options = {
          url: `${image.url}/full/${iiifSize}/0/default.jpg`,
          headers: { referer: referer },
        };
        archive.append(request(options), {
          name: `${image.label}.jpg`,
        });
      });

      archive.finalize();
    }).catch((error) => {
      console.error(error);
      throw new Error(error);
    });
  } else {
    console.log("No images found for work.");
    callback(null, {
      statusCode: 200,
      body: JSON.stringify({ final_destination: "null" }),
    });
  }
};

function downloadLink(key) {
  const s3 = new AWS.S3();
  const downloadLink = s3.getSignedUrl("getObject", {
    Bucket: bucket,
    Key: key,
    Expires: 82800,
  });
  return downloadLink;
}

async function sendEmail(email, downloadKey, referer) {
  const ses = new AWS.SES({ region: region });

  const emailParams = {
    Destination: {
      ToAddresses: [email],
    },
    Message: {
      Body: {
        Html: {
          Charset: "UTF-8",
          Data: `<a href=\"${downloadKey}\">Click here</a> for your download.`,
        },
        Text: { Data: `Click here for your download: \n\n ${downloadKey}` },
      },
      Subject: { Data: `Your download from ${referer} is ready` },
    },
    Source: senderEmail,
  };

  try {
    let key = await ses.sendEmail(emailParams).promise();
    console.log("Email sent: ", key);
  } catch (e) {
    console.error("Email could not be sent: ", e);
  }
  return;
}

exports.handler = async (event, context, callback) => {
  if (event.async) {
    console.log("Processing asynchronous request.");
    return processEvent(event, callback);
  } else {
    console.log("Synchronous request received. Re-invoking asynchronously.");
    event.async = true;
    console.log(JSON.stringify(event));
    const lambda = new AWS.Lambda();
    return await lambda.invoke({ 
      FunctionName: context.functionName, 
      InvocationType: "Event", 
      Payload: JSON.stringify(event)
    }).promise();
  }
}
