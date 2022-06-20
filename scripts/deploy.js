const { ethers } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account: ' + deployer.address);

    // Deploy Avaxies
    const Avaxies = await ethers.getContractFactory('Avaxies', {
        libraries: {
            UIntArrays: "0x0001f3EE0fdcdD43aa50F304b723BAe1f4BAD19d",
        },
    });
    const avaxies = await Avaxies.deploy();
    console.log('Avaxies deployed on ', avaxies.address);

    // Set trait names
    await avaxies.setTraitNames([
        ["Green","Gray","Pink","Purple","Red","Blue","DarkBlue","Orange","Yellow"],
        ["Antenna","Babylonia","Cuckoo","DeepSea","DualBlades","EggshellRouge","Hero","LeafBug","Parasite","Rosebud","Tealshell","UniCorn","Unko","Watermelon","Winghorn"],
        ["Axiekiss","Doubletalk","Hungrybird","Kissy","Lam","LittleOwl","NutCracker","PeaceMaker","Pincer","Piranha","Sailor","Silencewhisper","Squareteeth","Straight","Toothlessbite"],
        ["Blossom","Chubby","Confused","CoolGlasses","Dot","Gero","kotaro","LittleOwl","Lucas","Mavis","Nerd","Puppy","ScaryEyes","Sleepless","Topaz"],
        ["Belieber","BubbleMaker","Hollow","Lamb","Leafy","Nutcracler","Nyan","OceanEars","OceanEarsFront","Owl","PinkcheekS","Puppy","Swirl","Tassels","Tinyfan","Zen"],
        ["BackFlower","Balloon","Cupid","Fishy","GreenThorns","Mushy","PigeonPost","Pumpking","Ronin","Rosebud","SnailShell","SpikyWing","Sponge","Trispikes","Turnip"],
        ["Ant","CarrotTail","Cottontail","FishTail","Fishy","Gerbil","Grammas","Grassnake","Hare","HotButt","Latsune","Navaja","Pupae","ThornyCaterpillar","Yam"],
        ["BigYak","Fluffy","Normal","Snow","Spiky","Sumo","Wetdog"]
    ]);
    console.log('Trait names set');
}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})