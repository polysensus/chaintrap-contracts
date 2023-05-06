import { ethers } from "ethers";
const bytes = ethers.utils.arrayify;
export class TranscriptLocation {
  static tokenize(blocknumber, id) {
    return ethers.utils.solidityKeccak256(
      ["uint256", "uint16"],
      [blocknumber, id]
    );
  }
  constructor(token, blocknumber, id) {
    this.blocknumber = blocknumber;
    this.token = token;
    this.id = id;
  }
}
