using module ..\..\..\constants.ps1
using module ..\..\..\exceptions.ps1
using module ..\..\..\rlp\blocks.ps1
using module ..\..\..\rlp\headers.ps1
using module ..\..\..\rlp\receipts.ps1
using module ..\..\..\rlp\transactions.ps1
using module ..\..\..\utils\blocks.ps1
using module ..\..\..\utils\hexidecimal.ps1
using module ..\..\..\utils\receipts.ps1

class FrontierBlock(BaseBlock) {
    [State]$db
    [System.Object]$bloom_filter

    FrontierBlock([BlockHeader]$header, [State]$db, [FrontierTransaction[]]$transactions = $null, [BlockHeader[]]$uncles = $null) {
        $this.db = $db
        if ($transactions -eq $null) {
            $transactions = [FrontierTransaction[]]::new(0)
        }
        if ($uncles -eq $null) {
            $uncles = [BlockHeader[]]::new(0)
        }
        $this.bloom_filter = [BloomFilter]::new($header.bloom)
        $this.transaction_db = [Trie]::new($db, $header.transaction_root)
        $this.receipt_db = [Trie]::new($db, $header.receipt_root)
        [BaseBlock]::new($header, $transactions, $uncles)
    }

    validate_gas_limit() {
        $gas_limit = $this.header.gas_limit
        if ($gas_limit -lt [constants]::GAS_LIMIT_MINIMUM) {
            throw [ValidationError]::new("Gas limit $gas_limit is below minimum $([constants]::GAS_LIMIT_MINIMUM)")
        }
        if ($gas_limit -gt [constants]::GAS_LIMIT_MAXIMUM) {
            throw [ValidationError]::new("Gas limit $gas_limit is above maximum $([constants]::GAS_LIMIT_MAXIMUM)")
        }
        $parent_gas_limit = $this.GetParentHeader().gas_limit
        $diff = $gas_limit - $parent_gas_limit
        if ($diff -gt $parent_gas_limit / [constants]::GAS_LIMIT_ADJUSTMENT_FACTOR) {
            throw [ValidationError]::new("Gas limit $gas_limit difference to parent $parent_gas_limit is too big $diff")
        }
    }

    [void] validate() {
        if (-not $this.IsGenesis) {
            $parent_header = $this.GetParentHeader()
            $this.validate_gas_limit()
            [utils.validation]::validate_length_lte($this.header.extra_data, 32)
            if ($this.header.timestamp -lt $parent_header.timestamp) {
                throw [ValidationError]::new("`timestamp` is before the parent block's timestamp.`n- block  : $($this.header.timestamp)`n- parent : $($parent_header.timestamp). ")
            }
            elseif ($this.header.timestamp -eq $parent_header.timestamp) {
                throw [ValidationError]::new("`timestamp` is equal to the parent block's timestamp`n- block : $($this.header.timestamp)`n- parent: $($parent_header.timestamp). ")
            }
        }
        if ($this.uncles.Count -gt [constants]::MAX_UNCLES) {
            throw [ValidationError]::new("Blocks may have a maximum of $([constants]::MAX_UNCLES) uncles. Found $($this.uncles.Count).")
        }
        foreach ($uncle in $this.uncles) {
            $this.validate_uncle($uncle)
        }
        if (-not ($this.header.state_root -in $this.db.Keys)) {
            throw [ValidationError]::new("`state_root` was not found in the db.`n- state_root: $($this.header.state_root)")
        }
        $local_uncle_hash = [utils.keccak]::keccak([rlp]::encode($this.uncles))
        if ($local_uncle_hash -ne $this.header.uncles_hash) {
            throw [ValidationError]::new("`uncles_hash` and block `uncles` do not match.`n - num_uncles       : $($this.uncles.Count)`n - block uncle_hash : $([utils.hexidecimal]::encode_hex($local_uncle_hash))`n - header uncle_hash: $([utils.hexidecimal]::encode_hex($this.header.uncles_hash))")
        }
        [BaseBlock]::validate($this)
    }

    validate_uncle([BlockHeader]$uncle) {
        if ($uncle.block_number -ge $this.number) {
            throw [ValidationError]::new("Uncle number ($($uncle.block_number)) is higher than block number ($($this.number))")
        }
        try {
            $uncle_parent = $this.db[$uncle.parent_hash]
        }
        catch {
            throw [ValidationError]::new("Uncle ancestor not found: $([utils.hexidecimal]::encode_hex($uncle.parent_hash))")
        }
        $parent_header = [rlp]::decode($uncle_parent, [BlockHeader])
        if ($uncle.block_number -ne $parent_header.block_number + 1) {
            throw [ValidationError]::new("Uncle number ($($uncle.block_number)) is not one above ancestor's number ($($parent_header.block_number))")
        }
        if ($uncle.timestamp -lt $parent_header.timestamp) {
            throw [ValidationError]::new("Uncle timestamp ($($uncle.timestamp)) is before ancestor's timestamp ($($parent_header.timestamp))")
        }
        if ($uncle.gas_used -gt $uncle.gas_limit) {
            throw [ValidationError]::new("Uncle's gas usage ($($uncle.gas_used)) is above the limit ($($uncle.gas_limit))")
        }
    }

    [int] get_number() {
        return $this.header.block_number
    }

    [byte[]] get_hash() {
        return $this.header.hash
    }

    [BlockHeader] GetParentHeader() {
        $parent_header_bytes = $this.db[$this.header.parent_hash]
        return [rlp]::decode($parent_header_bytes, [BlockHeader])
    }

    static [Type] GetTransactionClass() {
        return [FrontierTransaction]
    }

    [int] GetCumulativeGasUsed() {
        if ($this.transactions.Length -gt 0) {
            return $this.receipts[-1].gas_used
        }
        else {
            return 0
        }
    }

    [FrontierReceipt[]] get_receipts() {
        return [utils.receipts]::GetReceiptsFromDB($this.receipt_db, [FrontierReceipt])
    }

    static [FrontierBlock] FromHeader([BlockHeader]$header, [State]$db) {
        if ($header.uncles_hash -eq [constants]::EMPTY_UNCLE_HASH) {
            $uncles = [BlockHeader[]]::new(0)
        }
        else {
            $uncles = [rlp]::decode($db[$header.uncles_hash], [BlockHeader[]])
        }
        $transaction_db = [Trie]::new($db, $header.transaction_root)
        $transactions = [utils.transactions]::GetTransactionsFromDB($transaction_db, [FrontierTransaction])
        return [FrontierBlock]::new($header, $transactions, $uncles, $db)
    }

    [FrontierBlock] AddTransaction([FrontierTransaction]$transaction, [Computation]$computation) {
        $logs = [Log[]]::new(0)
        foreach ($log_entry in $computation.get_log_entries()) {
            $logs += [Log]::new($log_entry[0], $log_entry[1], $log_entry[2])
        }
        if ($computation.error) {
            $tx_gas_used = $transaction.gas
        }
        else {
            $gas_remaining = $computation.get_gas_remaining()
            $gas_refund = $computation.get_gas_refund()
            $tx_gas_used = $transaction.gas - $gas_remaining - [Math]::Min($gas_refund, ($transaction.gas - $gas_remaining) / 2)
        }
        $gas_used = $this.header.gas_used + $tx_gas_used
        $receipt = [FrontierReceipt]::new(
            state_root=$computation.state_db.root_hash,
            gas_used=$gas_used,
            logs=$logs
        )
        $transaction_idx = $this.transactions.Length
        $index_key = [rlp]::encode($transaction_idx, [rlp]::sedes.big_endian_int)
        $this.transactions += $transaction
        $this.transaction_db[$index_key] = [rlp]::encode($transaction)
        $this.receipt_db[$index_key] = [rlp]::encode($receipt)
        $this.bloom_filter = $this.bloom_filter -bor $receipt.bloom_filter
        $this.header.transaction_root = $this.transaction_db.root_hash
        $this.header.state_root = $computation.state_db.root_hash
        $this.header.receipt_root = $this.receipt_db.root_hash
        $this.header.bloom = [int]$this.bloom_filter
        $this.header.gas_used = $gas_used
        return $this
    }

    [FrontierBlock] AddUncle([BlockHeader]$uncle) {
        $this.uncles += $uncle
        $this.header.uncles_hash = [utils.keccak]::keccak([rlp]::encode($this.uncles))
        return $this
    }

    [FrontierBlock] Mine([hashtable]$kwargs = @{}) {
        if ("uncles" -in $kwargs.Keys) {
            $this.uncles = $kwargs["uncles"]
            $kwargs["uncles_hash"] = [utils.keccak]::keccak([rlp]::encode($this.uncles))
        }
        $header = $this.header
        $provided_fields = [System.Collections.Generic.HashSet[string]]::new($kwargs.Keys)
        $known_fields = [System.Linq.Enumerable]::ToArray([System.Tuple[string,Type]]::new([BlockHeader]::GetFields()))
        $unknown_fields = $provided_fields - [System.Linq.Enumerable]::Select($known_fields, { $args[0][0] })
        if ($unknown_fields.Count -gt 0) {
            throw [System.AttributeError]::new("Unable to set the field(s) $([string]::Join(', ', $unknown_fields)) on the `BlockHeader` class. Received the following unexpected fields: $([string]::Join(', ', $unknown_fields)).")
        }
        foreach ($key in $kwargs.Keys) {
            $header.$key = $kwargs[$key]
        }
        $this.validate()
        return $this
    }
