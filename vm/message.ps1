using module ..\..\constants.ps1
using module ..\..\exceptions.ps1
using module ..\..\utils\validation.ps1

class Message {
    [byte[]]$origin
    [byte[]]$to
    [byte[]]$sender
    [int]$value
    [byte[]]$data
    [int]$gas
    [int]$gas_price
    [int]$depth
    [byte[]]$code
    [byte[]]$_code_address
    [byte[]]$_storage_address
    [bool]$should_transfer_value
    [System.Object]$logger = [logging]::getLogger('evm.vm.message.Message')

    Message([int]$gas, [int]$gas_price, [byte[]]$to, [byte[]]$sender, [int]$value, [byte[]]$data, [byte[]]$code, [byte[]]$origin = $null, [int]$depth = 0, [byte[]]$create_address = $null, [byte[]]$code_address = $null, [bool]$should_transfer_value = $false) {
        [utils.validation]::validate_uint256($gas)
        $this.gas = $gas
        [utils.validation]::validate_uint256($gas_price)
        $this.gas_price = $gas_price
        if ($to -ne [constants]::CREATE_CONTRACT_ADDRESS) {
            [utils.validation]::validate_canonical_address($to)
        }
        $this.to = $to
        [utils.validation]::validate_canonical_address($sender)
        $this.sender = $sender
        [utils.validation]::validate_uint256($value)
        $this.value = $value
        [utils.validation]::validate_is_bytes($data)
        $this.data = $data
        if ($origin -ne $null) {
            [utils.validation]::validate_canonical_address($origin)
        }
        $this._origin = $origin
        [utils.validation]::validate_is_integer($depth)
        [utils.validation]::validate_gte($depth, 0)
        $this.depth = $depth
        [utils.validation]::validate_is_bytes($code)
        $this.code = $code
        if ($create_address -ne $null) {
            [utils.validation]::validate_canonical_address($create_address)
        }
        $this._storage_address = $create_address
        if ($code_address -ne $null) {
            [utils.validation]::validate_canonical_address($code_address)
        }
        $this._code_address = $code_address
        [utils.validation]::validate_is_boolean($should_transfer_value)
        $this.should_transfer_value = $should_transfer_value
    }

    [bool] get_is_origin() {
        return $this.sender -eq $this.origin
    }

    [byte[]] get_origin() {
        if ($this._origin -ne $null) {
            return $this._origin
        }
        else {
            return $this.sender
        }
    }

    set_origin([byte[]]$value) {
        $this._origin = $value
    }

    [byte[]] get_code_address() {
        if ($this._code_address -ne $null) {
            return $this._code_address
        }
        else {
            return $this.to
        }
    }

    set_code_address([byte[]]$value) {
        $this._code_address = $value
    }

    [byte[]] get_storage_address() {
        if ($this._storage_address -ne $null) {
            return $this._storage_address
        }
        else {
            return $this.to
        }
    }

    set_storage_address([byte[]]$value) {
        $this._storage_address = $value
    }

    [bool] get_is_create() {
        return $this.to -eq [constants]::CREATE_CONTRACT_ADDRESS
    }
}
