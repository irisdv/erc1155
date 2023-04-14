use starknet::ContractAddress;

#[abi]
trait IERC1155Receiver {
    fn on_erc1155_received(
        operator: ContractAddress,
        from_: ContractAddress,
        id: u256,
        value: u256,
        data: Array::<felt252>
    ) -> felt252;
    fn on_erc1155_batch_received(
        operator: ContractAddress,
        from_: ContractAddress,
        ids: Array::<u256>,
        values: Array::<u256>,
        data: Array::<felt252>
    ) -> felt252;
}

#[abi]
trait IERC165 {
    fn supports_interface(interface_id: felt252) -> bool;
}
