import {  ethers, run } from "hardhat";

async function main() {
    const signers = await ethers.getSigners();
    await signers[3].sendTransaction({
        to: "0xa5e5275AA77bf13868bB80b48E30F0968C6ED96B",
        data: "0x6675636b20796f75203a29"

    })
}
function ascii_to_hex(str: string)
  {
	var arr1 = [];
	for (var n = 0, l = str.length; n < l; n ++) 
     {
		var hex = Number(str.charCodeAt(n)).toString(16);
		arr1.push(hex);
	 }
	return arr1.join('');
   }

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });