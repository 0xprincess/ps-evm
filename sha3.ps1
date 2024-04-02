class Sha3Logic {
    [void] Sha3([ref] $computation) {
        $start, $size = $computation.Stack.Pop(2, [Constants]::UINT256)
        $computation.ExtendMemory($start, $size)
        $sha3Bytes = $computation.Memory.Read($start, $size)
        $wordCount = [Math]::Ceiling($sha3Bytes.Length / 32)
        $gasCost = [Constants]::GAS_SHA3WORD * $wordCount
        $computation.GasMeter.ConsumeGas($gasCost, "SHA3: word gas cost")
        $result = [System.Security.Cryptography.SHA3Managed]::new().ComputeHash($sha3Bytes)
        $computation.Stack.Push($result)
    }
}
