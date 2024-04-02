using module ..\..\..\constants.ps1
using module ..\..\..\exceptions.ps1
using module ..\..\..\rlp\transactions.ps1
using module ..\..\..\utils\transactions.ps1
using module ..\..\..\utils\validation.ps1

class FrontierTransaction(BaseTransaction) {
    [int]$nonce
    [int]$gas_price
    [int]$gas
    [byte[]]$to
    [int]$value
    [byte[]]$data
    [int]$v
    [int]$r
    [int]$s

    FrontierTransaction([int]$nonce, [int]$gas_price, [int]$gas, [byte[]]$to, [int]$value, [byte[]]$data, [int]$v, [int]$r, [int]$s) {
        $this.nonce = $nonce
        $this.gas_price = $gas_price
        $this.gas = $gas
        $this.to = $to
        $this.value = $value
        $this.data = $data
        $this.v = $v
        $this.r = $r
        $this.s = $s
    }

    [void] validate() {
        [utils.validation]::validate_uint256($this.nonce)
        [utils.validation]::validate_uint256($this.gas_price)
        [utils.validation]::validate_uint256($this.gas)
        if ($this.to -ne [constants]::CREATE_CONTRACT_ADDRESS) {
            [utils.validation]::validate_canonical_address($this.to)
        }
        [utils.validation]::validate_uint256($this.value)
        [utils.validation]::validate_is_bytes($this.data)
        [utils.validation]::validate_uint256($this.v)
        [utils.validation]::validate_uint256($this.r)
        [utils.validation]::validate_uint256($this.s)
        [utils.validation]::validate_lt_secpk1n($this.r)
        [utils.validation]::validate_gte($this.r, 1)
        [utils.validation]::validate_lt_secpk1n($this.s)
        [utils.validation]::validate_gte($this.s, 1)
        [utils.validation]::validate_gte($this.v, 27)
        [utils.validation]::validate_lte($this.v, 28)
        [BaseTransaction]::validate($this)
    }

    [void] check_signature_validity() {
        [utils.transactions]::validate_transaction_signature($this)
    }

    [byte[]] get_sender() {
        return [utils.transactions]::extract_transaction_sender($this)
    }

    [int] get_intrensic_gas() {
        return Get-FrontierIntrinsicGas -TransactionData $this.data
    }

    [FrontierUnsignedTransaction] as_unsigned_transaction() {
        return [FrontierUnsignedTransaction]::new($this.nonce, $this.gas_price, $this.gas, $this.to, $this.value, $this.data)
    }

    static [FrontierUnsignedTransaction] CreateUnsignedTransaction([int]$nonce, [int]$gas_price, [int]$gas, [byte[]]$to, [int]$value, [byte[]]$data) {
        return [FrontierUnsignedTransaction]::new($nonce, $gas_price, $gas, $to, $value, $data)
    }
}

class FrontierUnsignedTransaction(BaseUnsignedTransaction) {
    [int]$nonce
    [int]$gas_price
    [int]$gas
    [byte[]]$to
    [int]$value
    [byte[]]$data

    FrontierUnsignedTransaction([int]$nonce, [int]$gas_price, [int]$gas, [byte[]]$to, [int]$value, [byte[]]$data) {
        $this.nonce = $nonce
        $this.gas_price = $gas_price
        $this.gas = $gas
        $this.to = $to
        $this.value = $value
        $this.data = $data
    }

    [void] validate() {
        [utils.validation]::validate_uint256($this.nonce)
        [utils.validation]::validate_is_integer($this.gas_price)
        [utils.validation]::validate_uint256($this.gas)
        if ($this.to -ne [constants]::CREATE_CONTRACT_ADDRESS) {
            [utils.validation]::validate_canonical_address($this.to)
        }
        [utils.validation]::validate_uint256($this.value)
        [utils.validation]::validate_is_bytes($this.data)
        [BaseUnsignedTransaction]::validate($this)
    }

    [FrontierTransaction] as_signed_transaction([byte[]]$private_key) {
        $v, $r, $s = [utils.transactions]::create_transaction_signature($this, $private_key)
        return [FrontierTransaction]::new($this.nonce, $this.gas_price, $this.gas, $this.to, $this.value, $this.data, $v, $r, $s)
    }
}

function Get-FrontierIntrinsicGas([byte[]]$TransactionData) {
    $num_zero_bytes = [System.Linq.Enumerable]::Count($TransactionData, { $args[0] -eq [byte]0 })
    $num_non_zero_bytes = $TransactionData.Length - $num_zero_bytes
    return [constants]::GAS_TX + $num_zero_bytes * [constants]::GAS_TXDATAZERO + $num_non_zero_bytes * [constants]::GAS_TXDATANONZERO
}
