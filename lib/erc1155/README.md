# Why the customisation ?

1. SolidStates contracts combine ERC165 and ERC1155 in the same contract. Yet
the reference diamond implementation puts the ERC165 implementation on the Loupe
facet. This means the Loupe facet and the SolidState facet have duplicate
methods and so can not both be added as facets.  The Loupe facet is a required
aspect of a Diamond. And the Loupe is specifically for introspection. That is
clearly the better home.
1. We want to be able to split up the token implementations. This is much
more composable if the erc 1155 methods are available on a libary.

The changes were inspired and guided by

https://dev.to/nohehf/handling-multiple-tokens-with-a-modern-solidity-architecture-via-diamonds-erc1155-1h7e