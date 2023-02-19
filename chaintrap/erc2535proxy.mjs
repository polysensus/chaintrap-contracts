import { ethers } from "ethers"

/**
 * This handler is only safe when accessing specific facet methods. When
 * accessing contract properties you will get the first found and the order is
 * arbitrary. Use getFacet to retrieve the specific contrac instance for the
 * facet you are interested in if you need to interact with the facets contract
 * in a general way.
 */
export class ERC2535DiamondFacetProxyHandler {

  constructor (diamondAddress, facetABIs, signerOrProvider) {
    this.diamondAddress = diamondAddress;
    this.interfaces = createFacetInterfaces(facetABIs);
    this.facets = {};
    for (const [name, abi] of Object.entries(this.interfaces)) {
      this.facets[name] = new ethers.Contract(diamondAddress, abi, signerOrProvider)
    }

    this.targetCache = new Map();
  }

  /**
   * A Reflect.get implementation proxying to the facet methods. This will
   * return properties on the diamond contract in preference to those on the
   * underlying facets. With the effect that facet specific methods and events
   * are proxied to the appropriate instance but generic contract interaction
   * happens with the diamond contract instance.
   * @param {*} target assumed to be the contract instance for the Diamon itself
   * @param {*} prop 
   * @param {*} receiver 
   * @returns 
   */
  get(target, prop, receiver) {
    // target is the instance being proxie. it should be a contract instance
    // bound on the diamond with the interface of the ERC 2535 itself. This will
    // mean that any generic abi calls etc will go to the diamon abi.

    if (prop in target)
      return Reflect.get(target, prop, receiver)

    if (this.targetCache.has(prop)) {
      const cachedTarget = this.targetCache.get(prop);
      return Reflect.get(cachedTarget, prop, receiver);
    }

    for (const candidateTarget of Object.values(this.facets)) {
      if (!(prop in candidateTarget)) continue

      this.targetCache.set(prop, candidateTarget);

      return Reflect.get(candidateTarget, prop, receiver)
    }
  }

  getFacet(name) {
    return this.facets[name];
  }

  getFacetInterface(name) {
    return this.interfaces[name];
  }
}

export function createERC2535Proxy(diamondAddress, diamondABI, facetABIs, signerOrProvider) {
  const diamond = new ethers.Contract(diamondAddress, diamondABI, signerOrProvider);
  const handler = new ERC2535DiamondFacetProxyHandler(diamondAddress, facetABIs, signerOrProvider);
  return new Proxy(diamond, handler);
}

/**
 * 
 * @param {object} facetABIs an object whose keys should be facet names and
 * whose values may be json abi descriptions or ethers.utils.Interface instances
 */
export function createFacetInterfaces(facetABIs) {

  const interfaces = {}

  for (const [name, abi] of Object.entries(facetABIs)) {
    interfaces[name] = new ethers.utils.Interface(abi)
  }
  return interfaces
}

/**
 * 
 * @param {string} diamond address of diamond ERC2535 proxy contract
 * @param {*} facetABIs an object whose keys should be facet names and
 * whose values may be json abi descriptions or ethers.utils.Interface instances
 */
export function createFacets(diamond, facetABIs, signerOrProvider) {
  const facets = {}
  for (const [name, abi] of createFacetInterfaces(facetABIs)) {
    facets[name] = new ethers.Contract(diamond, abi, signerOrProvider)
  }
  return facets;
}