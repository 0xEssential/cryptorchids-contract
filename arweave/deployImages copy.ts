import Arweave from 'arweave';
import key from '../arweave-key.json';
import * as fs from 'fs';
import * as path from 'path';
import glob from 'glob';
// Since v1.5.1 you're now able to call the init function for the web version without options. The current path will be used by default, recommended.
const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});

// arweave.wallets.jwkToAddress(key).then((address) => {
//   console.log(address);
//   //1seRanklLU_1VTGkEk7P0xAwMJfA7owA1JHW5KyZKlY
// });

const uploadAsset = async (filePath: string) => {
  const data = fs.readFileSync(path.resolve(__dirname, filePath));
  const transaction = await arweave.createTransaction({data: data}, key);
  transaction.addTag('Content-Type', 'image/png');

  await arweave.transactions.sign(transaction, key);

  const uploader = await arweave.transactions.getUploader(transaction);

  while (!uploader.isComplete) {
    await uploader.uploadChunk();
    console.log(
      `${uploader.pctComplete}% complete, ${uploader.uploadedChunks}/${uploader.totalChunks}`
    );
  }

  return transaction?.id;
};

const getHash = (filePath: string) => uploadAsset(filePath);

const getAsyncHash = async (filePath: string) => {
  const hash = await getHash(filePath);
  return Promise.resolve({[filePath]: hash});
};

const main = async () => {
  console.log(path.resolve(__dirname, './Dead/Images/'));
  const dead = glob.sync(path.resolve(__dirname, './Dead/Images/') + '/*.png');
  const alive = glob.sync(
    path.resolve(__dirname, './Flowering/Images/') + '/*.png'
  );

  const result = await Promise.all(
    ['./granum.png', ...dead, ...alive].map((filePath) =>
      getAsyncHash(filePath)
    )
  );

  console.log(result);
  return result;
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
