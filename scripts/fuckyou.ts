import {  ethers, run } from "hardhat";

async function main() {
    const signers = await ethers.getSigners();
    await signers[3].sendTransaction({
        to: "0xa5e5275AA77bf13868bB80b48E30F0968C6ED96B",
        data: "0x6675636b20796f75203a29"

    })
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });