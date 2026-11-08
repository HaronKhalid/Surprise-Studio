// Creates the bucket and makes only the processed `assets/` prefix publicly readable.
// Raw uploads (`uploads/`) stay private. Works against any S3-compatible store.
require('dotenv').config();
const { CreateBucketCommand, HeadBucketCommand, PutBucketPolicyCommand, S3Client } = require('@aws-sdk/client-s3');

async function main() {
  const bucket = process.env.STORAGE_BUCKET;
  const client = new S3Client({
    endpoint: process.env.STORAGE_ENDPOINT,
    region: process.env.STORAGE_REGION || 'auto',
    forcePathStyle: true,
    credentials: { accessKeyId: process.env.STORAGE_ACCESS_KEY, secretAccessKey: process.env.STORAGE_SECRET_KEY },
  });

  try {
    await client.send(new HeadBucketCommand({ Bucket: bucket }));
    console.log(`bucket "${bucket}" exists`);
  } catch {
    await client.send(new CreateBucketCommand({ Bucket: bucket }));
    console.log(`bucket "${bucket}" created`);
  }

  const policy = {
    Version: '2012-10-17',
    Statement: [
      {
        Effect: 'Allow',
        Principal: { AWS: ['*'] },
        Action: ['s3:GetObject'],
        Resource: [`arn:aws:s3:::${bucket}/assets/*`],
      },
    ],
  };
  await client.send(new PutBucketPolicyCommand({ Bucket: bucket, Policy: JSON.stringify(policy) }));
  console.log('public-read policy set on assets/*');
}

main().catch((e) => {
  console.error('storage init failed:', e.message);
  process.exit(1);
});
