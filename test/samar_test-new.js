const Samari = artifacts.require('Samari')

contract('Samari', (accounts) => {
  const maintainer = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const stranger = accounts[3];

  let samari

  beforeEach(async () => {
    samari = await Samari.new({ from: maintainer });
  });

  describe('DEFAULT_ADMIN_ROLE', (_msgSender) => {
    
  });

  describe('NOLIMIT_ROLE', () => {

  });

  describe('PAUSER_ROLE', () => {

  });

  describe('POOL_ROLE', () => {

  });

  describe('TOCENOMICS_ROLE', () => {

  });

  describe('antiwhale', () => {

  });

  describe('getRoleAdmin', () => {

  });

  describe('getRoleMember', () => {

  });

  describe('getRoleMemberCount', () => {

  });

  describe('grantRole', () => {

  });

  describe('hasRole', () => {

  });

  describe('maxFeeTotal', () => {

  });

  describe('otherFee', () => {

  });

  describe('paused', () => {

  });

  describe('proxycontract', () => {

  });

  describe('proxyenabled', () => {

  });

  describe('renounceRole', () => {

  });

  describe('revokeRole', () => {

  });

  describe('supportsInterface', () => {

  });

  describe('taxFee', () => {

  });

  describe('name', () => {

  });

  describe('symbol', () => {

  });

  describe('decimals', () => {

  });

  describe('totalSupply', () => {

  });

  describe('balanceOf', () => {

  });

  describe('transfer', () => {

  });

  describe('allowance', () => {

  });

  describe('approve', () => {

  });

  describe('transferFrom', () => {

  });

  describe('increaseAllowance', () => {

  });

  describe('decreaseAllowance', () => {

  });

  describe('isExcludedFromReward', () => {

  });

  describe('totalFees', () => {

  });

  describe('setproxyContract', () => {

  });

  describe('changeProxyState', () => {

  });

  describe('changeAntiWhaleState', () => {

  });

  describe('deliver', () => {

  });

  describe('reflectionFromToken', () => {

  });

  describe('tokenFromReflection', () => {

  });

  describe('excludeFromReward', () => {

  });

  describe('includeInReward', () => {

  });

  describe('excludeFromFee', () => {

  });

  describe('includeInFee', () => {

  });

  describe('setTaxFeePercent', () => {

  });

  describe('setOtherFeeFeePercent', () => {

  });

  describe('pause', () => {

  });

  describe('unpause', () => {

  });

  describe('isExcludedFromFee', () => {

  });
});
