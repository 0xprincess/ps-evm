using module ..\constants.ps1
using module ..\exceptions.ps1
using module ..\logic\invalid.ps1
using module ..\precompile.ps1
using module ..\utils\hexidecimal.ps1
using module ..\utils\numeric.ps1
using module gas_meter.ps1
using module memory.ps1
using module message.ps1
using module stack.ps1

class Computation {
    [VM]$vm
    [Message]$msg
    [Memory]$memory
    [Stack]$stack
    [GasMeter]$gas_meter
    [CodeStream]$code
    [System.Collections.Generic.List[Computation]]$children
    [byte[]]$_output = [byte[]]::new(0)
    [System.Exception]$error
    [System.Collections.Generic.List[tuple[byte[],System.Collections.Generic.List[int],byte[]]]]$log_entries
    [System.Collections.Generic.Dictionary[byte[],byte[]]]$accounts_to_delete
    [System.Object]$logger = [logging]::getLogger('evm.vm.computation.Computation')

    Computation([VM]$vm, [Message]$message) {
        $this.vm = $vm
        $this.msg = $message
        $this.memory = [Memory]::new()
        $this.stack = [Stack]::new()
        $this.gas_meter = [GasMeter]::new($message.gas)
        $this.children = [System.Collections.Generic.List[Computation]]::new()
        $this.log_entries = [System.Collections.Generic.List[tuple[byte[],System.Collections.Generic.List[int],byte[]]]]::new()
        $this.accounts_to_delete = [System.Collections.Generic.Dictionary[byte[],byte[]]]::new()
        $code = $message.code
        $this.code = [CodeStream]::new($code)
    }

    [bool] get_is_origin_computation() {
        return $this.msg.is_origin
    }

    [State] get_state_db() {
        return $this.vm.state_db
    }

    [Message] prepare_child_message([int]$gas, [byte[]]$to, [int]$value, [byte[]]$data, [byte[]]$code, [hashtable]$kwargs = @{}) {
        $kwargs['storage_address'] = $this.msg.storage_address
        $child_message = [Message]::new(
            gas=$gas,
            gas_price=$this.msg.gas_price,
            origin=$this.msg.origin,
            to=$to,
            value=$value,
            data=$data,
            code=$code,
            depth=$this.msg.depth + 1,
            @kwargs
        )
        return $child_message
    }

    extend_memory([int]$start_position, [int]$size) {
        [utils.validation]::validate_uint256($start_position)
        [utils.validation]::validate_uint256($size)
        $before_size = [utils.numeric]::ceil32($this.memory.Length)
        $after_size = [utils.numeric]::ceil32($start_position + $size)
        $before_cost = [utils.numeric]::memory_gas_cost($before_size)
$after_cost = [utils.numeric]::memory_gas_cost($after_size)
       if ($this.logger -ne $null) {
           $this.logger.debug("MEMORY: size ($before_size -> $after_size) | cost ($before_cost -> $after_cost)")
       }
       if ($size -gt 0) {
           if ($before_cost -lt $after_cost) {
               $gas_fee = $after_cost - $before_cost
               $this.gas_meter.consume_gas($gas_fee, "Expanding memory $before_size -> $after_size")
           }
           $this.memory.Extend($start_position, $size)
       }
   }

   [byte[]] get_output() {
       if ($this.error) {
           return [byte[]]::new(0)
       }
       else {
           return $this._output
       }
   }

   set_output([byte[]]$value) {
       $this._output = $value
   }

   register_account_for_deletion([byte[]]$beneficiary) {
       [utils.validation]::validate_canonical_address($beneficiary)
       if ($this.msg.storage_address -in $this.accounts_to_delete.Keys) {
           throw [System.ValueError]::new("Invariant. Should be impossible for an account to be registered for deletion multiple times")
       }
       $this.accounts_to_delete[$this.msg.storage_address] = $beneficiary
   }

   [System.Collections.Generic.IEnumerable[tuple[byte[],byte[]]]] get_accounts_for_deletion() {
       if ($this.error) {
           return $this.accounts_to_delete.GetEnumerator()
       }
       else {
           return [System.Linq.Enumerable]::Concat($this.accounts_to_delete.GetEnumerator(), [System.Linq.Enumerable]::SelectMany($this.children, { [tuple[byte[],byte[]]]($_.get_accounts_for_deletion()) }))
       }
   }

   add_log_entry([byte[]]$account, [int[]]$topics, [byte[]]$data) {
       [utils.validation]::validate_canonical_address($account)
       foreach ($topic in $topics) {
           [utils.validation]::validate_uint256($topic)
       }
       [utils.validation]::validate_is_bytes($data)
       $this.log_entries.Add(($account, $topics, $data))
   }

   [System.Collections.Generic.IEnumerable[tuple[byte[],System.Collections.Generic.List[int],byte[]]]] get_log_entries() {
       if ($this.error) {
           return [System.Linq.Enumerable]::Empty()
       }
       else {
           return [System.Linq.Enumerable]::Concat($this.log_entries, [System.Linq.Enumerable]::SelectMany($this.children, { [tuple[byte[],System.Collections.Generic.List[int],byte[]]]($_.get_log_entries()) }))
       }
   }

   [int] get_gas_refund() {
       if ($this.error) {
           return 0
       }
       else {
           return $this.gas_meter.gas_refunded + [System.Linq.Enumerable]::Sum($this.children, { $_.get_gas_refund() })
       }
   }

   [int] get_gas_used() {
       if ($this.error) {
           return $this.msg.gas
       }
       else {
           return [Math]::Max(0, $this.msg.gas - $this.gas_meter.gas_remaining)
       }
   }

   [int] get_gas_remaining() {
       if ($this.error) {
           return 0
       }
       else {
           return $this.gas_meter.gas_remaining
       }
   }

   [void] Enter() {
       if ($this.logger -ne $null) {
           $this.logger.debug("COMPUTATION STARTING: gas: $($this.msg.gas) | from: $('{0}' -f [utils.hexidecimal]::encode_hex($this.msg.sender)) | to: $('{0}' -f [utils.hexidecimal]::encode_hex($this.msg.to)) | value: $($this.msg.value)")
       }
   }

   [void] Exit([System.Exception]$exception_value) {
       if ($exception_value -and $exception_value -is [VMError]) {
           if ($this.logger -ne $null) {
               $this.logger.debug("COMPUTATION ERROR: gas: $($this.msg.gas) | from: $('{0}' -f [utils.hexidecimal]::encode_hex($this.msg.sender)) | to: $('{0}' -f [utils.hexidecimal]::encode_hex($this.msg.to)) | value: $($this.msg.value) | error: $exception_value")
           }
           $this.error = $exception_value
           $this.gas_meter.consume_gas($this.gas_meter.gas_remaining, "Zeroing gas due to VM Exception: $exception_value")
           return
       }
       elseif ($exception_value -eq $null) {
           if ($this.logger -ne $null) {
               $this.logger.debug("COMPUTATION SUCCESS: from: $('{0}' -f [utils.hexidecimal]::encode_hex($this.msg.sender)) | to: $('{0}' -f [utils.hexidecimal]::encode_hex($this.msg.to)) | value: $($this.msg.value) | gas-used: $($this.msg.gas - $this.gas_meter.gas_remaining) | gas-remaining: $($this.gas_meter.gas_remaining)")
           }
       }
   }
}
