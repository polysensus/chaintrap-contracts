const func  = async ({getNamedAccounts, deployments}) => {

  const {deploy} = deployments;

  const {deployer} = await getNamedAccounts();

  await deploy('Arena', {
    from: deployer,
    log: true,
  });
};

module.exports = {
  func: func,
  default: func,
}

module.exports.func.tags = ['Arena'];