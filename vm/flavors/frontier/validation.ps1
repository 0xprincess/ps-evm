using module ..\..\..\constants.ps1
using module ..\..\..\exceptions.ps1
using module ..\..\..\utils\validation.ps1

function validate_frontier_transaction([VM]$vm, [FrontierTransaction]$transaction) {
    $transaction.validate()
    $vm.validate_transaction($transaction)
    $gas_cost = $transaction.gas * $transaction.gas_price
    $sender_balance = $vm.state_db.get_balance($transaction.sender)
    if ($sender_balance -lt $gas_cost) {
        throw [ValidationError]::new("Sender account balance cannot afford txn gas: `$($transaction.sender)`")
    }
    $total_cost = $transaction.value + $gas_cost
    if ($sender_balance -lt $total_cost) {
        throw [ValidationError]::new("Sender account balance cannot afford txn")
    }
    if ($vm.block.header.gas_used + $transaction.gas -gt $vm.block.header.gas_limit) {
        throw [ValidationError]::new("Transaction exceeds gas limit")
    }
    if ($vm.state_db.get_nonce($transaction.sender) -ne $transaction.nonce) {
        throw [ValidationError]::new("Invalid transaction nonce")
    }
}
