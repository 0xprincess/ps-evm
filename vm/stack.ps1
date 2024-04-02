using module ..\..\constants.ps1
using module ..\..\exceptions.ps1
using module ..\..\utils\validation.ps1

class Stack {
    [System.Collections.Generic.List[System.Object]]$values
    [System.Object]$logger = [logging]::getLogger('evm.vm.stack.Stack')

    Stack() {
        $this.values = [System.Collections.Generic.List[System.Object]]::new()
    }

    [int] get_length() {
        return $this.values.Count
    }

    push([System.Object]$value) {
        if ($this.values.Count -gt 1023) {
            throw [FullStack]::new("Stack limit reached")
        }
        [utils.validation]::validate_stack_item($value)
        $this.values.Add($value)
    }

    [System.Object[]] pop([int]$num_items = 1, [Type]$type_hint = $null) {
        try {
            $result = [System.Object[]]::new($num_items)
            for ($i = 0; $i -lt $num_items; $i++) {
                $value = $this.values[$this.values.Count - 1]
                $this.values.RemoveAt($this.values.Count - 1)
                if ($type_hint -eq [constants]::UINT256) {
                    if ($value -is [int]) {
                        $result[$i] = $value
                    }
                    else {
                        $result[$i] = [utils.numeric]::big_endian_to_int($value)
                    }
                }
                elseif ($type_hint -eq [constants]::BYTES) {
                    if ($value -is [byte[]]) {
                        $result[$i] = $value
                    }
                    else {
                        $result[$i] = [utils.numeric]::int_to_big_endian($value)
                    }
                }
                elseif ($type_hint -eq $null) {
                    $result[$i] = $value
                }
                else {
                    throw [System.TypeError]::new("Unknown type_hint: $type_hint. Must be one of $([constants]::UINT256), $([constants]::BYTES)")
                }
            }
            if ($num_items -eq 1) {
                return $result[0]
            }
            else {
                return $result
            }
        }
        catch [System.IndexOutOfRangeException] {
            throw [InsufficientStack]::new("No stack items")
        }
    }

    swap([int]$position) {
        try {
            $idx = -1 * $position - 1
            $temp = $this.values[$this.values.Count - 1]
            $this.values[$this.values.Count - 1] = $this.values[$idx]
            $this.values[$idx] = $temp
        }
        catch [System.IndexOutOfRangeException] {
            throw [InsufficientStack]::new("Insufficient stack items for SWAP$position")
        }
    }

    dup([int]$position) {
        try {
            $idx = -1 * $position
            $value = $this.values[$idx]
            $this.push($value)
        }
        catch [System.IndexOutOfRangeException] {
            throw [InsufficientStack]::new("Insufficient stack items for DUP$position")
        }
    }
}
