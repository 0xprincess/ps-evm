using module ..\chain.ps1
using module ..\constants.ps1
using module ..\exceptions.ps1
using module ..\logic\invalid.ps1
using module ..\rlp\blocks.ps1
using module ..\state.ps1
using module ..\utils\hexidecimal.ps1
using module ..\utils\numeric.ps1

class VM {
    [System.Object]$db
    [System.Object]$opcodes
    [System.Object]$_block_class

    VM([System.Object]$header, [System.Object]$db) {
        if ($db -eq $null) {
            throw [System.ValueError]::new('VM classes must have a `db`')
        }
        $this.db = $db
        $block_class = $this.GetBlockClass()
        $this.block = $block_class::FromHeader($header, $db)
    }

    static [System.Object] Configure([string]$name = $null, [hashtable]$overrides = @{}) {
        if ($name -eq $null) {
            $name = $this.GetType().Name
        }
        foreach ($key in $overrides.Keys) {
            if (-not $this.PSObject.Properties.Name.Contains($key)) {
                throw [System.TypeError]::new("The VM.configure cannot set attributes that are not already present on the base class. The attribute `$key` was not found on the base class `$($this.GetType().FullName)`")
            }
        }
        return [scriptblock]::Create("using module .\base.ps1; class $name : $($this.GetType().FullName) { $($overrides.GetEnumerator() | ForEach-Object { "`n    `$$($_.Key) = `$_`$($_.Value)" }) }")
    }

    [System.Object]$_block
    [System.Object]$state_db

    [System.Object] get_block() {
        if ($this._block -eq $null) {
            throw [System.AttributeError]::new('No block property set')
        }
        return $this._block
    }

    set_block([System.Object]$value) {
        $this._block = $value
        $this.state_db = [State]::new($this.db, $value.header.state_root)
    }

    [System.Object] get_logger() {
        return [logging]::getLogger("evm.vm.base.VM.$($this.GetType().Name)")
    }

    [System.Object] apply_transaction([System.Object]$transaction) {
        $computation = $this.execute_transaction($transaction)
        $this.block = $this.block.AddTransaction($transaction, $computation)
        return $computation
    }

    [System.Object] execute_transaction([System.Object]$transaction) {
        throw [System.NotImplementedError]::new()
    }

    [System.Object] apply_create_message([System.Object]$message) {
        throw [System.NotImplementedError]::new()
    }

    [System.Object] apply_message([System.Object]$message) {
        throw [System.NotImplementedError]::new()
    }

    [System.Object] apply_computation([System.Object]$message) {
        throw [System.NotImplementedError]::new()
    }

    [double] get_block_reward([int]$block_number) {
        return [constants]::BLOCK_REWARD
    }

    [double] get_nephew_reward([int]$block_number) {
        return [constants]::NEPHEW_REWARD
    }

    [System.Object] import_block([System.Object]$block) {
        $this.configure_header(
            coinbase=$block.header.coinbase,
            gas_limit=$block.header.gas_limit,
            timestamp=$block.header.timestamp,
            extra_data=$block.header.extra_data,
            mix_hash=$block.header.mix_hash,
            nonce=$block.header.nonce
        )
        foreach ($transaction in $block.transactions) {
            $this.apply_transaction($transaction)
        }
        foreach ($uncle in $block.uncles) {
            $this.block.AddUncle($uncle)
        }
        return $this.mine_block()
    }

    [System.Object] mine_block([hashtable]$args = @{}, [hashtable]$kwargs = @{}) {
        $block = $this.block
        $block.Mine($args, $kwargs)

        if ($block.number -gt 0) {
            $block_reward = $this.get_block_reward($block.number) + ($block.uncles.Count * $this.get_nephew_reward($block.number))
            $this.state_db.delta_balance($block.header.coinbase, $block_reward)
            $this.logger.debug("BLOCK REWARD: $block_reward -> $($block.header.coinbase)")

            foreach ($uncle in $block.uncles) {
                $uncle_reward = [constants]::BLOCK_REWARD * ([constants]::UNCLE_DEPTH_PENALTY_FACTOR + $uncle.block_number - $block.number) / [constants]::UNCLE_DEPTH_PENALTY_FACTOR
                $this.state_db.delta_balance($uncle.coinbase, $uncle_reward)
                $this.logger.debug("UNCLE REWARD REWARD: $uncle_reward -> $($uncle.coinbase)")
            }

            $this.logger.debug("BEFORE ROOT: $($block.header.state_root)")
            $block.header.state_root = $this.state_db.root_hash
            $this.logger.debug("STATE_ROOT: $($block.header.state_root)")
        }

        return $block
    }

    [System.Type] GetTransactionClass() {
        return $this.GetBlockClass().GetTransactionClass()
    }

    [System.Object] create_transaction([object[]]$args, [hashtable]$kwargs) {
        return $this.GetTransactionClass().new($args, $kwargs)
    }

    [System.Object] create_unsigned_transaction([object[]]$args, [hashtable]$kwargs) {
        return $this.GetTransactionClass()::CreateUnsignedTransaction($args, $kwargs)
    }

    validate_transaction([System.Object]$transaction) {
        throw [System.NotImplementedError]::new()
    }

    [System.Type] GetBlockClass() {
        if ($this._block_class -eq $null) {
            throw [System.AttributeError]::new('No `_block_class` has been set for this VM')
        }
        return $this._block_class
    }

    [System.Object] GetBlockByHeader([System.Object]$block_header) {
        return $this.GetBlockClass()::FromHeader($block_header, $this.db)
    }

    [System.Object] GetAncestorHash([int]$block_number) {
        $ancestor_depth = $this.block.number - $block_number
        if ($ancestor_depth -gt 256 -or $ancestor_depth -lt 1) {
            return [constants]::EMPTY_BYTES
        }
        $h = [Chain]::GetBlockHeaderByHash($this.db, $this.block.header.parent_hash)
        while ($h.block_number -ne $block_number) {
            $h = [Chain]::GetBlockHeaderByHash($this.db, $h.parent_hash)
        }
        return $h.hash
    }

    static [System.Object] CreateHeaderFromParent([System.Object]$parent_header, [hashtable]$header_params = @{}) {
        throw [System.NotImplementedError]::new()
    }

    configure_header([hashtable]$header_params = @{}) {
        throw [System.NotImplementedError]::new()
    }

    [System.Object] snapshot() {
        return $this.state_db.snapshot()
    }

    [void] revert([System.Object]$snapshot) {
        $this.state_db.revert($snapshot)
    }

    [System.Object] GetOpcodeFn([int]$opcode) {
        try {
            return $this.opcodes[$opcode]
        }
        catch {
            return [InvalidOpcode]::new($opcode)
        }
    }
}
