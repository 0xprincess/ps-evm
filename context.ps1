class ContextLogic {
    [void] Balance([ref] $computation) {
        $address = $computation.Stack.Pop([Constants]::BYTES)
        $balance = $this.StateDB.GetBalance($address)
        $computation.Stack.Push($balance)
    }

    [void] Origin([ref] $computation) {
        $computation.Stack.Push($computation.Msg.Origin)
    }

    [void] Address([ref] $computation) {
        $computation.Stack.Push($computation.Msg.StorageAddress)
    }

    [void] Caller([ref] $computation) {
        $computation.Stack.Push($computation.Msg.Sender)
    }

    [void] Callvalue([ref] $computation) {
        $computation.Stack.Push($computation.Msg.Value)
    }

    [void] Calldataload([ref] $computation) {
        $startPosition = $computation.Stack.Pop([Constants]::UINT256)
        $value = $computation.Msg.Data[$startPosition..($startPosition+31)]
        $paddedValue = [Collections.Generic.List[byte]]::new($value.Length)
        $paddedValue.AddRange($value)
        $paddedValue.AddRange([byte[]]::new(32 - $value.Length))
        $normalizedValue = $paddedValue | Where-Object { $_ -ne 0 }
        $computation.Stack.Push([System.BitConverter]::ToUInt64($normalizedValue, 0))
    }

    [void] Calldatasize([ref] $computation) {
        $computation.Stack.Push($computation.Msg.Data.Length)
    }

    [void] Calldatacopy([ref] $computation) {
        $memStart, $callStart, $size = $computation.Stack.Pop(3, [Constants]::UINT256)
        $computation.ExtendMemory($memStart, $size)
        $wordCount = [Math]::Ceiling($size / 32) 
        $copyCost = $wordCount * [Constants]::GAS_COPY
        $computation.GasMeter.ConsumeGas($copyCost, "Data copy fee")
        $value = $computation.Msg.Data[$callStart..($callStart+$size-1)]
        $computation.Memory.Write($memStart, $size, $value)
    }

    [void] Codesize([ref] $computation) {
        $computation.Stack.Push($computation.Code.Length)
    }

    [void] Codecopy([ref] $computation) {
        $memStart, $codeStart, $size = $computation.Stack.Pop(3, [Constants]::UINT256)
        $computation.ExtendMemory($memStart, $size)
        $wordCount = [Math]::Ceiling($size / 32)
        $copyCost = [Constants]::GAS_COPY * $wordCount
        $computation.GasMeter.ConsumeGas($copyCost, "CODECOPY: word gas cost")
        $code = $computation.Code[$codeStart..($codeStart+$size-1)]
        $paddedCode = [byte[]]::new(32)
        [System.Buffer]::BlockCopy($code, 0, $paddedCode, 0, $code.Length)
        $computation.Memory.Write($memStart, $size, $paddedCode)
    }

    [void] Gasprice([ref] $computation) {
        $computation.Stack.Push($computation.Msg.GasPrice)
    }

    [void] Extcodesize([ref] $computation) {
        $account = $computation.Stack.Pop([Constants]::BYTES)
        $codeSize = $this.StateDB.GetCode($account).Length
        $computation.Stack.Push($codeSize)
    }

    [void] Extcodecopy([ref] $computation) {
        $account = $computation.Stack.Pop([Constants]::BYTES)
        $memStart, $codeStart, $size = $computation.Stack.Pop(3, [Constants]::UINT256)
        $computation.ExtendMemory($memStart, $size)
        $wordCount = [Math]::Ceiling($size / 32)
        $copyCost = [Constants]::GAS_COPY * $wordCount
        $computation.GasMeter.ConsumeGas($copyCost, "EXTCODECOPY: word gas cost")
        $code = $this.StateDB.GetCode($account)
        $codeByte = $code[$codeStart..($codeStart+$size-1)]
        $paddedCode = [byte[]]::new(32)
        [System.Buffer]::BlockCopy($codeByte, 0, $paddedCode, 0, $codeByte.Length)
        $computation.Memory.Write($memStart, $size, $paddedCode)
    }
}
