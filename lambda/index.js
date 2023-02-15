const _archiver = require("archiver");
const AWS = require("aws-sdk");
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
const today = new Date().toLocaleDateString("en-us", {
  weekday: "long",
  year: "numeric",
  month: "short",
  day: "numeric",
});

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

    request.method = "GET";
    request.path += `${index}/_doc/${workId}?_source=title,accession_number,file_sets`;
    request.headers["host"] = elasticsearchEndpoint;
    request.headers["Content-Type"] = "application/json";

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

async function getWork(workId) {
  const request = await makeRequest(workId);
  console.log("request: ", request);
  const response = await awsFetch(request);
  console.log("response: ", response);
  const work = JSON.parse(response)?._source;
  console.log("work: ", work);
  return work;
}

async function imageUrls(fileSets) {
  const urls = fileSets
    .filter((fs) => fs.representative_image_url != null && fs.accession_number != null)
    .map((fs) => ({
      label: fs.accession_number,
      url: fs.representative_image_url,
    }));

  console.log("imageUrls: ", urls);

  return urls;
}

exports.handler = async (event, _context, callback) => {
  console.log("event: ", event);

  const workId = event.params.querystring.workId;
  const email = event.params.querystring.email;
  const width = event.params.querystring.width
    ? event.params.querystring.width
    : defaultWidth;
  const referer = event.params.header.Referer || event.params.header.referer;

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
  const work = await getWork(workId);
  const images = await imageUrls(work.file_sets);

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

        const params = {
          email,
          downloadKey,
          referer,
          workId,
          today,
          title: work?.title || "[Untitled]",
          accession: work?.accession_number,
        };
        console.log("params: ", params);
        sendEmail(params);
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

async function sendEmail(options) {
  const ses = new AWS.SES({ region: region });

  const emailParams = {
    Source: `Northwestern University Libraries <${senderEmail}>`,
    Template: process.env.template,
    Destination: {
      ToAddresses: [options.email],
    },
    TemplateData: JSON.stringify(options),
  };

  console.log("sendTemplatedEmail params: ", emailParams);

  try {
    let key = await ses.sendTemplatedEmail(emailParams).promise();
    console.log("Email sent: ", key);
  } catch (e) {
    console.error("Email could not be sent: ", e);
  }
  return;
}
