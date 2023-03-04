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
    this._handler_diamondAddress = diamondAddress;
    this._handler_interfaces = createFacetInterfaces(facetABIs);
    this._handler_filterCache = new Map();

    // topic[0] -> interface.event entry
    this._handler_eventInterface = new Map();

    const facets = {};
    for (const [name, abi] of Object.entries(this._handler_interfaces)) {
      facets[name] = new ethers.Contract(diamondAddress, abi, signerOrProvider)
    }
    this._handler_facets = facets;

    this._handler_targetCache = new Map();
  }

  /**
   * A Reflect.get implementation proxying to the facet methods. This will
   * return properties on the diamond contract in preference to those on the
   * underlying facets. If neither the diamond nor the facets have the prop we
   * fall back to looking in the handler itself. With the effect that facet
   * specific methods and events are proxied to the appropriate instance but
   * generic contract interaction happens with the diamond contract instance.
   * And there is an escape hatch for implementing helpers on this hanlder
   * class.
   * @param {*} target assumed to be the contract instance for the Diamon itself
   * @param {*} prop to get from diamond or its facets or finally this handler
   * @param {*} receiver 
   * @returns 
   */
  get(target, prop, receiver) {
    // target is the instance being proxie. it should be a contract instance
    // bound on the diamond with the interface of the ERC 2535 itself. This will
    // mean that any generic abi calls etc will go to the diamon abi.

    if (prop in target)
      return Reflect.get(target, prop, receiver)

    if (this._handler_targetCache.has(prop)) {
      const cachedTarget = this._handler_targetCache.get(prop);
      return Reflect.get(cachedTarget, prop, receiver);
    }

    for (const candidateTarget of Object.values(this._handler_facets)) {
      if (!(prop in candidateTarget)) continue

      this._handler_targetCache.set(prop, candidateTarget);

      return Reflect.get(candidateTarget, prop, receiver)
    }

    if (prop in this) {
      this._handler_targetCache.set(prop, this) // garbage collector cycles ...
      return Reflect.get(this, prop, receiver);
    }
  }

  getFacet(name) {
    return this._handler_facets[name];
  }

  getFacetInterface(name) {
    return this._handler_interfaces[name];
  }

  getFilter(signature, ...args) {

    const cache = this._handler_filterCache;
    if (cache.has(signature))
      return cache.get(signature)(args);

    for (const f of Object.values(this._handler_facets)) {
      if (signature in f.filters) {
        const filter = f.filters[signature];
        cache.set(signature, filter);
        return filter;
      }
    }
    return undefined;
  }

  getEventInterface(event) {
    const cache = this._handler_eventInterface;

    const topic = event?.topics?.[0]
    if (cache.has(topic))
      return cache.get(topic);

    let err;
    for (const iface of Object.values(this._handler_interfaces)) {
      try {
        iface.getEvent(topic) // throws if it doesn't exist
        cache[topic] = iface
        return iface
      } catch (err) {}
    }

    // throw the last actual err we got from ethers or a generic one for the
    // case we have interfaces to search.
    throw err || new Error(`event topic ${topic} not found`);
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