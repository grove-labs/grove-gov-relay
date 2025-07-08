# 🏛️🌳 Grove Gov Relay 🏛️🌳
This repository contains infrastructure necessary to process cross-chain execution of governance proposals.

The codebase uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework. In order to run tests, deploy contracts, or perform other operations, use standard [Foundry](https://github.com/foundry-rs/foundry) commands.

## ⚙️ Components
### 🚦 Executors
Executors serve as admins of the bridged domain instances of the protocol. <br>They are responsible for storying the queue of proposals passed from the host domain governance and their execution. <br> They manage bridged domain protocol instance using standard payload pattern.

## ⚖️ Licensing

This repository is a fork of the sparkdotfi/spark-alm-controller. All code in this repository is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0), which requires that modifications to the code must be made available under the same license. See the [LICENSE](LICENSE) file for more details.
