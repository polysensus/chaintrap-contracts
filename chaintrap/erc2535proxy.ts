import { ethers, Signer, Provider } from "ethers";

interface FacetABI {
  [key: string]: any; // ABI description
}

interface FacetInterfaces {
  [key: string]: ethers.utils.Interface;
}

export class ERC2535DiamondFacetProxyHandler {
  private _handler_diamondAddress: string;
  private _handler_interfaces: FacetInterfaces;
  private _handler_filterCache: Map<string, Function>;
  private _handler_eventInterface: Map<string, ethers.utils.Interface>;
  private _handler_facets: { [key: string]: ethers.Contract };
  private _handler_targetCache: Map<
    string,
    ethers.Contract | ERC2535DiamondFacetProxyHandler
  >;

  constructor(
    diamondAddress: string,
    facetABIs: FacetInterfaces,
    signerOrProvider: Signer | Provider
  ) {
    this._handler_diamondAddress = diamondAddress;
    this._handler_interfaces = createFacetInterfaces(facetABIs);
    this._handler_filterCache = new Map();
    this._handler_eventInterface = new Map();

    const facets: { [key: string]: ethers.Contract } = {};
    for (const [name, abi] of Object.entries(this._handler_interfaces)) {
      facets[name] = new ethers.Contract(diamondAddress, abi, signerOrProvider);
    }
    this._handler_facets = facets;
    this._handler_targetCache = new Map();
  }

  get(target: any, prop: PropertyKey, receiver: any): any {
    if (prop in target) return Reflect.get(target, prop, receiver);

    if (this._handler_targetCache.has(prop)) {
      const cachedTarget = this._handler_targetCache.get(prop);
      return Reflect.get(cachedTarget, prop, receiver);
    }

    for (const candidateTarget of Object.values(this._handler_facets)) {
      if (!(prop in candidateTarget)) continue;

      this._handler_targetCache.set(prop, candidateTarget);

      return Reflect.get(candidateTarget, prop, receiver);
    }

    if (prop in this) {
      this._handler_targetCache.set(prop, this);
      return Reflect.get(this, prop, receiver);
    }
  }

  getFacet(name: string): ethers.Contract {
    return this._handler_facets[name];
  }

  getFacetInterface(name: string): ethers.utils.Interface {
    return this._handler_interfaces[name];
  }

  getFilter(signature: string, ...args: any[]): Function | undefined {
    const cache = this._handler_filterCache;
    if (cache.has(signature)) return cache.get(signature)?.(...args);

    for (const f of Object.values(this._handler_facets)) {
      if (signature in f.filters) {
        const filter = f.filters[signature];
        cache.set(signature, filter);
        return filter(...args);
      }
    }
    return undefined;
  }

  getEventInterface(event: any): ethers.utils.Interface {
    const cache = this._handler_eventInterface;
    const topic = event?.topics?.[0];
    if (cache.has(topic)) return cache.get(topic)!;

    let err: any;
    for (const iface of Object.values(this._handler_interfaces)) {
      try {
        iface.getEvent(topic); // throws if it doesn't exist
        cache[topic] = iface;
        return iface;
      } catch (error) {
        err = error;
      }
    }
    throw err || new Error(`event topic ${topic} not found`);
  }
}

export function createERC2535Proxy(
  diamondAddress: string,
  diamondABI: ethers.ContractInterface,
  facetABIs: FacetInterfaces,
  signerOrProvider: Signer | Provider
): ethers.Contract {
  const diamond = new ethers.Contract(
    diamondAddress,
    diamondABI,
    signerOrProvider
  );
  const handler = new ERC2535DiamondFacetProxyHandler(
    diamondAddress,
    facetABIs,
    signerOrProvider
  );
  return new Proxy(diamond, handler);
}

export function createFacetInterfaces(
  facetABIs: FacetInterfaces
): FacetInterfaces {
  const interfaces: FacetInterfaces = {};

  for (const [name, abi] of Object.entries(facetABIs)) {
    interfaces[name] = new ethers.utils.Interface(abi);
  }
  return interfaces;
}

export function createFacets(
  diamond: string,
  facetABIs: FacetInterfaces,
  signerOrProvider: Signer | Provider
): { [key: string]: ethers.Contract } {
  const facets: { [key: string]: ethers.Contract } = {};
  for (const [name, abi] of Object.entries(createFacetInterfaces(facetABIs))) {
    facets[name] = new ethers.Contract(diamond, abi, signerOrProvider);
  }
  return facets;
}
