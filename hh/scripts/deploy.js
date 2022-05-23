async function main() {
  const Arena = await ethers.getContractFactory("Arena");
  const arena = await Arena.deploy();
  await arena.deployed();

  console.log("Arena:", arena.address);
}

main().then(()=>process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
