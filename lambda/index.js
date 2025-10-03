const _archiver = require("archiver");
const { S3Client } = require("@aws-sdk/client-s3");
const { SESClient, SendTemplatedEmailCommand } = require("@aws-sdk/client-ses");
const { Upload } = require("@aws-sdk/lib-storage");
const { getWork } = require("./get-work");
const path = require("path");
const request = require("request");
const uuid = require("node-uuid");

const bucket = process.env.archiveBucket;
const region = process.env.region;
const senderEmail = process.env.senderEmail;
const defaultWidth = 1000;
const maxWidthAllowed = 10001;
const today = new Date().toLocaleDateString("en-us", {
  weekday: "long",
  year: "numeric",
  month: "short",
  day: "numeric",
});

const getUrl = (key) => {
  return `https://${bucket}.s3.${region}.amazonaws.com/${key}`;
}

const streamTo = (key) => {
  const stream = require("stream");
  const pass = new stream.PassThrough();
  const client = new S3Client({ region });
  const upload = new Upload({
    client: client,
    params: {
      Bucket: bucket,
      Key: key,
      Body: pass,
      ContentType: "application/zip",
      ACL: "public-read",
    },
  });

  upload
    .on("httpUploadProgress", (progress) => {
      console.log("progress", progress);
    })
    .done()
    .then((data) => {
      console.log(`File written to:  ${getUrl(key)}`);
    })
    .catch((err) => {
      console.error("Error", err);
    })
    .finally(() => {
      pass.destroy();
    });

  return pass;
};

async function imageUrls(fileSets) {
  const urls = fileSets
    .filter((fs) => fs.representative_image_url != null && fs.accession_number != null)
    .map((fs) => ({
      label: fs.accession_number,
      url: fs.representative_image_url,
    }));

  return urls;
}

exports.handler = async (event, _context, callback) => {

  const workId = event.params.querystring.workId;
  const email = event.params.querystring.email;
  const width = event.params.querystring.width
    ? event.params.querystring.width
    : defaultWidth;
  const referer = event.params.header.Referer || event.params.header.referer;

  console.log(`Creating zip for workId: ${workId}`);
  console.log(`email: ${email}`);
  console.log(`width: ${width}`);
  console.log(`referer: ${referer}`);

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
  return getUrl(key);
}

async function sendEmail(options) {
  const ses = new SESClient({ region });
  const command = new SendTemplatedEmailCommand({
    Source: `Northwestern University Libraries <${senderEmail}>`,
    Template: process.env.template,
    Destination: {
      ToAddresses: [options.email]
    },
    TemplateData: JSON.stringify(options)
  });
  try {
    let key = await ses.send(command);
    console.log("Email sent: ", key);
  } catch (e) {
    console.error("Email could not be sent: ", e);
  }
  return;
}
