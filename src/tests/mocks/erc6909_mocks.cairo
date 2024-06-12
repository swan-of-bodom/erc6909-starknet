#[starknet::contract]
pub mod DualCaseERC6909Mock {
  use starknet::ContractAddress;
  use erc6909::token::erc6909::{ERC6909Component};

  /// Component
  component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

  /// ABI of Components
  #[abi(embed_v0)]
  impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
  #[abi(embed_v0)]
  impl ERC6909TokenSupplyImpl = ERC6909Component::ERC6909TokenSupplyImpl<ContractState>;
  #[abi(embed_v0)]
  impl ERC6909CamelImpl = ERC6909Component::ERC6909CamelImpl<ContractState>;

  /// Internal logic
  impl InternalImpl = ERC6909Component::InternalImpl<ContractState>;

  #[storage]
  struct Storage { 
      #[substorage(v0)]
      erc6909: ERC6909Component::Storage
  }

  #[event]
  #[derive(Drop, starknet::Event)]
  enum Event {
      #[flat]
      ERC6909Event: ERC6909Component::Event
  }

  #[constructor]
  fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256)  {
      self.erc6909._mint(receiver, id, amount);
  }
}

