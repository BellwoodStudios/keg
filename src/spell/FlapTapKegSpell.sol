pragma solidity =0.6.7 >=0.5.12;

import "lib/dss-interfaces/src/dapp/DSPauseAbstract.sol";
import "lib/dss-interfaces/src/dss/IlkRegistryAbstract.sol";
import "lib/dss-interfaces/src/dss/VatAbstract.sol";
import "lib/dss-interfaces/src/dss/FlapAbstract.sol";
import "lib/dss-interfaces/src/dss/VowAbstract.sol";
import "lib/dss-interfaces/src/dss/ChainlogAbstract.sol";
import "lib/dss-interfaces/src/dss/DaiAbstract.sol";
import "lib/dss-interfaces/src/dss/DaiJoinAbstract.sol";

import "../Keg.sol";
import "../FlapTap.sol";

contract SpellAction {
    // Office hours enabled if true
    bool constant public officeHours = true;

    // MAINNET ADDRESSES
    //
    // The contracts in this list should correspond to MCD core contracts, verify
    //  against the current release list at:
    //     https://changelog.makerdao.com/releases/mainnet/active/contracts.json
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    // decimals & precision
    uint256 constant THOUSAND = 10 ** 3;
    uint256 constant MILLION  = 10 ** 6;
    uint256 constant WAD      = 10 ** 18;
    uint256 constant RAY      = 10 ** 27;
    uint256 constant RAD      = 10 ** 45;

    // Many of the settings that change weekly rely on the rate accumulator
    // described at https://docs.makerdao.com/smart-contract-modules/rates-module
    // To check this yourself, use the following rate calculation (example 8%):
    //
    // $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'
    //
    // A table of rates can be found at
    //    https://ipfs.io/ipfs/QmefQMseb3AiTapiAKKexdKHig8wroKuZbmLtPLv4u2YwW
    //
    uint256 constant ZERO_PERCENT_RATE            = 1000000000000000000000000000;

    modifier limited {
        if (officeHours) {
            uint day = (block.timestamp / 1 days + 3) % 7;
            require(day < 5, "Can only be cast on a weekday");
            uint hour = block.timestamp / 1 hours % 24;
            require(hour >= 14 && hour < 21, "Outside office hours");
        }
        _;
    }

    function execute() external limited {

        // TODO Bump version
        CHANGELOG.setVersion("X.X.X");

        // Keg
        address MCD_VAT               = CHANGELOG.getAddress("MCD_VAT");
        address MCD_DAI               = CHANGELOG.getAddress("MCD_DAI");
        address MCD_JOIN_DAI          = CHANGELOG.getAddress("MCD_JOIN_DAI");
        address MCD_VOW               = CHANGELOG.getAddress("MCD_VOW");
        address MCD_FLAP              = CHANGELOG.getAddress("MCD_FLAP");

        address MCD_KEG               = address(new Keg(MCD_DAI));
        address MCD_FLAP_TAP          = address(new FlapTap(KegAbstract(MCD_KEG), DaiJoinAbstract(MCD_JOIN_DAI), MCD_FLAP, "FLAP", 2 * WAD / 10)); // 20%

        require(address(FlapTap(MCD_FLAP_TAP).flapper()) == MCD_FLAP,     "flap-doesnt-match");
        require(address(FlapTap(MCD_FLAP_TAP).vat())     == MCD_VAT,      "vat-doesnt-match");
        require(address(FlapTap(MCD_FLAP_TAP).daiJoin()) == MCD_JOIN_DAI, "dai-join-doesnt-match");
        require(address(FlapTap(MCD_FLAP_TAP).keg())     == MCD_KEG,      "keg-doesnt-match");


        // Allow FlapTap to vow
        FlapAbstract(MCD_FLAP_TAP).rely(MCD_VOW);
        // Allow Flap to FlapTap
        FlapAbstract(MCD_FLAP).rely(MCD_FLAP_TAP);
        // De-allow Flap to vow
        FlapAbstract(MCD_FLAP).deny(MCD_VOW);

        // change the flapper
        VowAbstract(MCD_VOW).file("flapper", MCD_FLAP_TAP);

        // Set the flight
        // TODO

        CHANGELOG.setAddress("MCD_FLAP_TAP", MCD_FLAP_TAP);
        CHANGELOG.setAddress("MCD_KEG", MCD_KEG);
    }
}

contract FlapTapKegSpell {
    ChainlogAbstract constant CHANGELOG =
    ChainlogAbstract(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    // TODO add back the immutable
    DSPauseAbstract  public pause;
    address          public action;
    bytes32          public tag;
    uint256          public expiration;
    uint256          public eta;
    bytes            public sig;
    bool             public done;

    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/makerdao/community/ed4b0067a116ff03c0556d5e95dca69773ee7fe4/governance/votes/Community%20Executive%20vote%20-%20December%2020%2C%202020.md -q -O - 2>/dev/null)"
    string constant public description =
    "2021-01-20 MakerDAO Executive Spell | Hash: 0xe9fXXXXXXXXXXXXX";

    function officeHours() external view returns (bool) {
        return SpellAction(action).officeHours();
    }

    constructor() public {
        pause = DSPauseAbstract(CHANGELOG.getAddress("MCD_PAUSE"));
        sig = abi.encodeWithSignature("execute()");
        bytes32 _tag;
        address _action = action = address(new SpellAction());
        assembly { _tag := extcodehash(_action) }
        tag = _tag;
        expiration = block.timestamp + 30 days;
    }

    function nextCastTime() external view returns (uint256 castTime) {
        require(eta != 0, "DSSSpell/spell-not-scheduled");
        castTime = block.timestamp > eta ? block.timestamp : eta; // Any day at XX:YY

        if (SpellAction(action).officeHours()) {
            uint256 day    = (castTime / 1 days + 3) % 7;
            uint256 hour   = castTime / 1 hours % 24;
            uint256 minute = castTime / 1 minutes % 60;
            uint256 second = castTime % 60;

            if (day >= 5) {
                castTime += (6 - day) * 1 days;                 // Go to Sunday XX:YY
                castTime += (24 - hour + 14) * 1 hours;         // Go to 14:YY UTC Monday
                castTime -= minute * 1 minutes + second;        // Go to 14:00 UTC
            } else {
                if (hour >= 21) {
                    if (day == 4) castTime += 2 days;           // If Friday, fast forward to Sunday XX:YY
                    castTime += (24 - hour + 14) * 1 hours;     // Go to 14:YY UTC next day
                    castTime -= minute * 1 minutes + second;    // Go to 14:00 UTC
                } else if (hour < 14) {
                    castTime += (14 - hour) * 1 hours;          // Go to 14:YY UTC same day
                    castTime -= minute * 1 minutes + second;    // Go to 14:00 UTC
                }
            }
        }
    }

    function schedule() external {
        require(block.timestamp <= expiration, "DSSSpell/spell-has-expired");
        require(eta == 0, "DSSSpell/spell-already-scheduled");
        eta = block.timestamp + DSPauseAbstract(pause).delay();
        pause.plot(action, tag, sig, eta);
    }

    function cast() external {
        require(!done, "DSSSpell/spell-already-cast");
        done = true;
        pause.exec(action, tag, sig, eta);
    }
}