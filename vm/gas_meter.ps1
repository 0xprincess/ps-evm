using module ..\..\constants.ps1
using module ..\..\exceptions.ps1
using module ..\..\utils\validation.ps1

class GasMeter {
    [int]$start_gas
    [int]$gas_refunded
    [int]$gas_remaining
    [System.Object]$logger = [logging]::getLogger('evm.gas.GasMeter')

    GasMeter([int]$start_gas) {
        [utils.validation]::validate_uint256($start_gas)
        $this.start_gas = $start_gas
        $this.gas_remaining = $start_gas
        $this.gas_refunded = 0
    }

    consume_gas([int]$amount, [string]$reason) {
        if ($amount -lt 0) {
            throw [ValidationError]::new("Gas consumption amount must be positive")
        }
        if ($amount -gt $this.gas_remaining) {
            throw [OutOfGas]::new([string]::Format("Out of gas: Needed {0} - Remaining {1} - Reason: {2}", $amount, $this.gas_remaining, $reason))
        }
        $this.gas_remaining -= $amount
        if ($this.logger -ne $null) {
            $this.logger.trace("GAS CONSUMPTION: {0} - {1} -> {2} ({3})", $this.gas_remaining + $amount, $amount, $this.gas_remaining, $reason)
        }
    }

    return_gas([int]$amount) {
        if ($amount -lt 0) {
            throw [ValidationError]::new("Gas return amount must be positive")
        }
        $this.gas_remaining += $amount
        if ($this.logger -ne $null) {
            $this.logger.trace("GAS RETURNED: {0} + {1} -> {2}", $this.gas_remaining - $amount, $amount, $this.gas_remaining)
        }
    }

    refund_gas([int]$amount) {
        if ($amount -lt 0) {
            throw [ValidationError]::new("Gas refund amount must be positive")
        }
        $this.gas_refunded += $amount
        if ($this.logger -ne $null) {
            $this.logger.trace("GAS REFUND: {0} + {1} -> {2}", $this.gas_refunded - $amount, $amount, $this.gas_refunded)
        }
    }
}
