import 'package:abidock_mvx/abidock_mvx.dart';

const String abiJson = r'''
{
  "buildInfo": {
    "rustc": {
      "version": "1.66.0-nightly",
      "commitHash": "b8c35ca26b191bb9a9ac669a4b3f4d3d52d97fb1",
      "commitDate": "2022-10-15",
      "channel": "Nightly",
      "short": "rustc 1.66.0-nightly (b8c35ca26 2022-10-15)"
    },
    "contractCrate": {
      "name": "pair",
      "version": "0.0.0"
    },
    "framework": {
      "name": "multiversx-sc",
      "version": "0.39.4"
    }
  },
  "name": "Pair",
  "constructor": {
    "inputs": [
      {
        "name": "first_token_id",
        "type": "TokenIdentifier"
      },
      {
        "name": "second_token_id",
        "type": "TokenIdentifier"
      },
      {
        "name": "router_address",
        "type": "Address"
      },
      {
        "name": "router_owner_address",
        "type": "Address"
      },
      {
        "name": "total_fee_percent",
        "type": "u64"
      },
      {
        "name": "special_fee_percent",
        "type": "u64"
      },
      {
        "name": "initial_liquidity_adder",
        "type": "Address"
      },
      {
        "name": "admins",
        "type": "variadic<Address>",
        "multi_arg": true
      }
    ]
  },
  "endpoints": [
    {
      "name": "addInitialLiquidity",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "inputs": []
    },
    {
      "name": "addLiquidity",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "inputs": [
        {
          "name": "first_token_amount_min",
          "type": "BigUint"
        },
        {
          "name": "second_token_amount_min",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": ""
    },
    {
      "name": "removeLiquidity",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "inputs": [
        {
          "name": "first_token_amount_min",
          "type": "BigUint"
        },
        {
          "name": "second_token_amount_min",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": ""
    },
    {
      "name": "removeLiquidityAndBuyBackAndBurnToken",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "inputs": [
        {
          "name": "token_to_buyback_and_burn",
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "outputs": []
    },
    {
      "name": "swapNoFeeAndForward",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "inputs": [
        {
          "name": "token_out",
          "type": "TokenIdentifier"
        },
        {
          "name": "destination_address",
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "outputs": []
    },
    {
      "name": "swapTokensFixedInput",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "inputs": [
        {
          "name": "token_out",
          "type": "TokenIdentifier"
        },
        {
          "name": "amount_out_min",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": ""
    },
    {
      "name": "swapTokensFixedOutput",
      "mutability": "mutable",
      "payableInTokens": [
        "*"
      ],
      "inputs": [
        {
          "name": "token_out",
          "type": "TokenIdentifier"
        },
        {
          "name": "amount_out",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": ""
    },
    {
      "name": "setLpTokenIdentifier",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "token_identifier",
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "getTokensForGivenPosition",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "liquidity",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "getReservesAndTotalSupply",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "BigUint"
        },
        {
          "type": "BigUint"
        },
        {
          "type": "BigUint"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getAmountOut",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "token_in",
          "type": "TokenIdentifier"
        },
        {
          "name": "amount_in",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "BigUint"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "getAmountIn",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "token_wanted",
          "type": "TokenIdentifier"
        },
        {
          "name": "amount_wanted",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "BigUint"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "getEquivalent",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "token_in",
          "type": "TokenIdentifier"
        },
        {
          "name": "amount_in",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "BigUint"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "getFeeState",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "bool"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "whitelist",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "address",
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "removeWhitelist",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "address",
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "addTrustedSwapPair",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "pair_address",
          "type": "Address"
        },
        {
          "name": "first_token",
          "type": "TokenIdentifier"
        },
        {
          "name": "second_token",
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "removeTrustedSwapPair",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "first_token",
          "type": "TokenIdentifier"
        },
        {
          "name": "second_token",
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "docs": [
        "`fees_collector_cut_percentage` of the special fees are sent to the fees_collector_address SC",
        "",
        "For example, if special fees is 5%, and fees_collector_cut_percentage is 10%,",
        "then of the 5%, 10% are reserved, and only the rest are split between other pair contracts."
      ],
      "name": "setupFeesCollector",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "fees_collector_address",
          "type": "Address"
        },
        {
          "name": "fees_collector_cut_percentage",
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "setFeeOn",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "enabled",
          "type": "bool"
        },
        {
          "name": "fee_to_address",
          "type": "Address"
        },
        {
          "name": "fee_token",
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "getFeeDestinations",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "variadic<tuple<Address,TokenIdentifier>>",
          "multi_result": true
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getTrustedSwapPairs",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "variadic<tuple<TokenPair,Address>>",
          "multi_result": true
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getWhitelistedManagedAddresses",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "variadic<Address>",
          "multi_result": true
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getFeesCollectorAddress",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getFeesCollectorCutPercentage",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "setStateActiveNoSwaps",
      "mutability": "mutable",
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": [],
      "outputs": []
    },
    {
      "name": "setFeePercents",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "total_fee_percent",
          "type": "u64"
        },
        {
          "name": "special_fee_percent",
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "getLpTokenIdentifier",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getTotalFeePercent",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getSpecialFee",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getRouterManagedAddress",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getFirstTokenId",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getSecondTokenId",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "TokenIdentifier"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getTotalSupply",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "BigUint"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getInitialLiquidtyAdder",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "Option<Address>"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getReserve",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "token_id",
          "type": "TokenIdentifier"
        }
      ],
      "outputs": [
        {
          "type": "BigUint"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "getSafePriceCurrentIndex",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "u32"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "updateAndGetTokensForGivenPositionWithSafePrice",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "liquidity",
          "type": "BigUint"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        },
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "updateAndGetSafePrice",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "input",
          "type": "EsdtTokenPayment"
        }
      ],
      "outputs": [
        {
          "type": "EsdtTokenPayment"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "setLockingDeadlineEpoch",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "new_deadline",
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "setLockingScAddress",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "new_address",
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "setUnlockEpoch",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "new_epoch",
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "getLockingScAddress",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getUnlockEpoch",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "getLockingDeadlineEpoch",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "u64"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    },
    {
      "name": "addAdmin",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "address",
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "removeAdmin",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "address",
          "type": "Address"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "updateOwnerOrAdmin",
      "onlyOwner": true,
      "mutability": "mutable",
      "inputs": [
        {
          "name": "previous_owner",
          "type": "Address"
        }
      ],
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "getPermissions",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "address",
          "type": "Address"
        }
      ],
      "outputs": [
        {
          "type": "u32"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": []
    },
    {
      "name": "addToPauseWhitelist",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "address_list",
          "type": "variadic<Address>",
          "multi_arg": true
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "removeFromPauseWhitelist",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "address_list",
          "type": "variadic<Address>",
          "multi_arg": true
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "outputs": []
    },
    {
      "name": "pause",
      "mutability": "mutable",
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": [],
      "outputs": []
    },
    {
      "name": "resume",
      "mutability": "mutable",
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": [],
      "outputs": []
    },
    {
      "name": "getState",
      "mutability": "readonly",
      "outputs": [
        {
          "type": "State"
        }
      ],
      "onlyOwner": false,
      "title": "",
      "payableInTokens": [],
      "inputs": []
    }
  ],
  "events": [
    {
      "identifier": "swap",
      "inputs": [
        {
          "name": "token_in",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "token_out",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "caller",
          "type": "Address",
          "indexed": true
        },
        {
          "name": "epoch",
          "type": "u64",
          "indexed": true
        },
        {
          "name": "swap_event",
          "type": "SwapEvent"
        }
      ]
    },
    {
      "identifier": "swap_no_fee_and_forward",
      "inputs": [
        {
          "name": "token_id_out",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "caller",
          "type": "Address",
          "indexed": true
        },
        {
          "name": "epoch",
          "type": "u64",
          "indexed": true
        },
        {
          "name": "swap_no_fee_and_forward_event",
          "type": "SwapNoFeeAndForwardEvent"
        }
      ]
    },
    {
      "identifier": "add_liquidity",
      "inputs": [
        {
          "name": "first_token",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "second_token",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "caller",
          "type": "Address",
          "indexed": true
        },
        {
          "name": "epoch",
          "type": "u64",
          "indexed": true
        },
        {
          "name": "add_liquidity_event",
          "type": "AddLiquidityEvent"
        }
      ]
    },
    {
      "identifier": "remove_liquidity",
      "inputs": [
        {
          "name": "first_token",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "second_token",
          "type": "TokenIdentifier",
          "indexed": true
        },
        {
          "name": "caller",
          "type": "Address",
          "indexed": true
        },
        {
          "name": "epoch",
          "type": "u64",
          "indexed": true
        },
        {
          "name": "remove_liquidity_event",
          "type": "RemoveLiquidityEvent"
        }
      ]
    }
  ],
  "hasCallback": false,
  "types": {
    "AddLiquidityEvent": {
      "type": "struct",
      "fields": [
        {
          "name": "caller",
          "type": "Address"
        },
        {
          "name": "first_token_id",
          "type": "TokenIdentifier"
        },
        {
          "name": "first_token_amount",
          "type": "BigUint"
        },
        {
          "name": "second_token_id",
          "type": "TokenIdentifier"
        },
        {
          "name": "second_token_amount",
          "type": "BigUint"
        },
        {
          "name": "lp_token_id",
          "type": "TokenIdentifier"
        },
        {
          "name": "lp_token_amount",
          "type": "BigUint"
        },
        {
          "name": "lp_supply",
          "type": "BigUint"
        },
        {
          "name": "first_token_reserves",
          "type": "BigUint"
        },
        {
          "name": "second_token_reserves",
          "type": "BigUint"
        },
        {
          "name": "block",
          "type": "u64"
        },
        {
          "name": "epoch",
          "type": "u64"
        },
        {
          "name": "timestamp",
          "type": "u64"
        }
      ]
    },
    "EsdtTokenPayment": {
      "type": "struct",
      "fields": [
        {
          "name": "token_identifier",
          "type": "TokenIdentifier"
        },
        {
          "name": "token_nonce",
          "type": "u64"
        },
        {
          "name": "amount",
          "type": "BigUint"
        }
      ]
    },
    "PriceObservation": {
      "type": "struct",
      "fields": [
        {
          "name": "first_token_reserve_accumulated",
          "type": "BigUint"
        },
        {
          "name": "second_token_reserve_accumulated",
          "type": "BigUint"
        },
        {
          "name": "weight_accumulated",
          "type": "u64"
        },
        {
          "name": "recording_round",
          "type": "u64"
        }
      ]
    },
    "RemoveLiquidityEvent": {
      "type": "struct",
      "fields": [
        {
          "name": "caller",
          "type": "Address"
        },
        {
          "name": "first_token_id",
          "type": "TokenIdentifier"
        },
        {
          "name": "first_token_amount",
          "type": "BigUint"
        },
        {
          "name": "second_token_id",
          "type": "TokenIdentifier"
        },
        {
          "name": "second_token_amount",
          "type": "BigUint"
        },
        {
          "name": "lp_token_id",
          "type": "TokenIdentifier"
        },
        {
          "name": "lp_token_amount",
          "type": "BigUint"
        },
        {
          "name": "lp_supply",
          "type": "BigUint"
        },
        {
          "name": "first_token_reserves",
          "type": "BigUint"
        },
        {
          "name": "second_token_reserves",
          "type": "BigUint"
        },
        {
          "name": "block",
          "type": "u64"
        },
        {
          "name": "epoch",
          "type": "u64"
        },
        {
          "name": "timestamp",
          "type": "u64"
        }
      ]
    },
    "State": {
      "type": "enum",
      "variants": [
        {
          "name": "Inactive",
          "discriminant": 0
        },
        {
          "name": "Active",
          "discriminant": 1
        },
        {
          "name": "PartialActive",
          "discriminant": 2
        }
      ]
    },
    "SwapEvent": {
      "type": "struct",
      "fields": [
        {
          "name": "caller",
          "type": "Address"
        },
        {
          "name": "token_id_in",
          "type": "TokenIdentifier"
        },
        {
          "name": "token_amount_in",
          "type": "BigUint"
        },
        {
          "name": "token_id_out",
          "type": "TokenIdentifier"
        },
        {
          "name": "token_amount_out",
          "type": "BigUint"
        },
        {
          "name": "fee_amount",
          "type": "BigUint"
        },
        {
          "name": "token_in_reserve",
          "type": "BigUint"
        },
        {
          "name": "token_out_reserve",
          "type": "BigUint"
        },
        {
          "name": "block",
          "type": "u64"
        },
        {
          "name": "epoch",
          "type": "u64"
        },
        {
          "name": "timestamp",
          "type": "u64"
        }
      ]
    },
    "SwapNoFeeAndForwardEvent": {
      "type": "struct",
      "fields": [
        {
          "name": "caller",
          "type": "Address"
        },
        {
          "name": "token_id_in",
          "type": "TokenIdentifier"
        },
        {
          "name": "token_amount_in",
          "type": "BigUint"
        },
        {
          "name": "token_id_out",
          "type": "TokenIdentifier"
        },
        {
          "name": "token_amount_out",
          "type": "BigUint"
        },
        {
          "name": "destination",
          "type": "Address"
        },
        {
          "name": "block",
          "type": "u64"
        },
        {
          "name": "epoch",
          "type": "u64"
        },
        {
          "name": "timestamp",
          "type": "u64"
        }
      ]
    },
    "TokenPair": {
      "type": "struct",
      "fields": [
        {
          "name": "first_token",
          "type": "TokenIdentifier"
        },
        {
          "name": "second_token",
          "type": "TokenIdentifier"
        }
      ]
    }
  }
}
''';

SmartContractAbi? _abi;

SmartContractAbi get abi {
  _abi ??= SmartContractAbi.fromJson(abiJson);
  return _abi!;
}
