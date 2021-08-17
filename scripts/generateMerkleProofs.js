const { GoogleSpreadsheet } = require('google-spreadsheet');
const creds = require('./sheet_secret.json');
const sheetconfig = require('./sheet_config.json');
const { MerkleTree } = require('merkletreejs');
const { BigNumber, utils } = require('ethers');
const { keccak_256 } = require('js-sha3');
const fs = require('fs');

const storeData = (data, path) => {
    try {
      fs.writeFileSync(path, JSON.stringify(data))
    } catch (err) {
      console.error(err)
    }
  }



async function GenerateProofs()
{
    try{
        const doc = new GoogleSpreadsheet(sheetconfig.sheet);
        await doc.useServiceAccountAuth(creds);
        await doc.loadInfo(); 
    
        var sheet = doc.sheetsByIndex[0];
        var entries = sheet.rowCount;
        console.log("Loaded: " + sheet.title + " with " + entries + " rows");
        console.log("Getting rows");
        var rows = await sheet.getRows();
        const leaves = [];
        const rows2 = [];
        rows.forEach((row) => {
            if(row.HolderAddress.length > 0 && !row.Finalbalance.includes("-")){
                rows2.push(row);
            }
        });

        rows2.forEach((row, index) => (leaves.push(utils.solidityKeccak256(['uint256', 'address', 'uint256'], [index, row.HolderAddress, utils.parseUnits(row.Finalbalance, 9)]).substr(2),'hex')));
        const tree = new MerkleTree(leaves, keccak_256);
        console.log(tree.getHexRoot());
        console.log("Adding new sheet")
        var tmp = tree.getHexProof(leaves[2]);
        console.log(tmp.toString());
        //const newsheet = await doc.addSheet({ title: 'MerkleProof sheet!', headerValues: ['index', 'address', 'amount', 'proof'] });
        //console.log("Adding rows to sheet");
        var obj = [];
        rows.forEach(async(row, index) => { obj.push({ index: index, address: row.HolderAddress, amount: utils.parseUnits(row.Finalbalance, 9).toString(), proof: tree.getHexProof(leaves[index])})});
        storeData(obj, "test.json");
        //rows.forEach(async(row, index) => {await newsheet.addRows({ index: index, address: row.HolderAddress, amount: utils.parseUnits(row.Finalbalance, 9), proof: tree.getHexProof(leaves[index])})
        //newsheet.save()});    
    }
    catch(e){
        console.log(e);
    }
    finally {

    }
};
GenerateProofs().then();