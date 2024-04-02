class MemoryLogic {
    [void] Mstore([ref] $computation) {
        $start = $computation.Stack.Pop([Constants]::UINT256)
        $value = $computation.Stack.Pop([Constants]::BYTES)

        $paddedValue = [byte[]]::new(32, 0)
        [System.Buffer]::BlockCopy($value, 0, $paddedValue, 0, $value.Length)
        $normalizedValue = $paddedValue[-32..-1]

        $computation.ExtendMemory($start, 32)
        $computation.Memory.Write($start, 32, $normalizedValue)
    }

    [void] Mstore8([ref] $computation) {
        $start = $computation.Stack.Pop([Constants]::UINT256)
        $value = $computation.Stack.Pop([Constants]::BYTES)

        $paddedValue = [byte[]]::new(1, 0)
        [System.Buffer]::BlockCopy($value, 0, $paddedValue, 0, 1)
        $computation.ExtendMemory($start, 1)
        $computation.Memory.Write($start, 1, $paddedValue)
    }

    [void] Mload([ref] $computation) {
        $start = $computation.Stack.Pop([Constants]::UINT256)
        $computation.ExtendMemory($start, 32)
        $value = $computation.Memory.Read($start, 32)
        $computation.Stack.Push($value)
    }

    [void] Msize([ref] $computation) {
        $computation.Stack.Push($computation.Memory.Length)
    }
}
