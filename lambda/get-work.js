const { HttpRequest } = require("@smithy/protocol-http");
const { NodeHttpHandler } = require("@smithy/node-http-handler");
const { SignatureV4 } = require("@smithy/signature-v4");
const { defaultProvider } = require("@aws-sdk/credential-provider-node");
const { Sha256 } = require("@aws-crypto/sha256-js");

const region = process.env.region;
const elasticsearchEndpoint = process.env.elasticsearchEndpoint;
const index = process.env.indexName;

async function makeRequest(workId) {
  const url = new URL(`https://${elasticsearchEndpoint}/`);

  const request = new HttpRequest({
    protocol: url.protocol,
    hostname: url.hostname,
    port: url.port ? Number(url.port) : undefined,
    method: "GET",
    path: `/${index}/_doc/${encodeURIComponent(workId)}`,
    query: {
      _source: "title,accession_number,file_sets"
    },
    headers: {
      host: url.hostname,
      "content-type": "application/json"
    }
  });

  try {
    const signer = new SignatureV4({
      credentials: defaultProvider(),
      region,
      service: "es",
      sha256: Sha256
    });
    return await signer.sign(request);
  } catch (err) {
    console.error("Returning unsigned request: ", err);
    return request;
  }
}

async function awsFetch(request) {
  const handler = new NodeHttpHandler();
  const { response } = await handler.handle(request);
  return streamToString(response.body);
}

function streamToString(stream) {
  return new Promise((resolve, reject) => {
    let data = "";
    stream.on("data", (chunk) => (data += Buffer.from(chunk).toString("utf8")));
    stream.on("end", () => resolve(data));
    stream.on("error", reject);
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

module.exports = { getWork };
