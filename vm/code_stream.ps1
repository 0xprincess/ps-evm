using module ..\evm.ps1
using module ..\opcode_values.ps1
using module ..\utils\validation.ps1

class CodeStream {
    [System.IO.MemoryStream]$stream
    [int]$depth_processed
    [System.Object]$logger = [logging]::getLogger('evm.vm.CodeStream')
    [System.Collections.Generic.HashSet[int]]$invalid_positions

    CodeStream([byte[]]$code_bytes) {
        [utils.validation]::validate_is_bytes($code_bytes)
        $this.stream = [System.IO.MemoryStream]::new($code_bytes)
        $this.invalid_positions = [System.Collections.Generic.HashSet[int]]::new()
        $this.depth_processed = 0
    }

    [byte[]] read([int]$size) {
        return $this.stream.Read($size)
    }

    [int] get_length() {
        return $this.stream.Length
    }

    [System.Object] GetEnumerator() {
        return $this
    }

    [int] MoveNext() {
        $next_opcode_byte = $this.read(1)
        if ($next_opcode_byte.Length -gt 0) {
            return [System.Convert]::ToInt32($next_opcode_byte[0])
        }
        else {
            return [opcode_values]::STOP
        }
    }

    [int] peek() {
        $current_pc = $this.pc
        $next_opcode = $this.MoveNext()
        $this.pc = $current_pc
        return $next_opcode
    }

    [int] get_pc() {
        return $this.stream.Position
    }

    set_pc([int]$value) {
        $this.stream.Seek([Math]::Min($value, $this.get_length()), [System.IO.SeekOrigin]::Begin)
    }

    pc {
        get { return $this.get_pc() }
        set { $this.set_pc($value) }
    }

    [System.Object] seek([int]$pc) {
        $anchor_pc = $this.pc
        $this.pc = $pc
        try {
            return $this
        }
        finally {
            $this.pc = $anchor_pc
        }
    }

    [bool] is_valid_opcode([int]$position) {
        if ($position -ge $this.get_length()) {
            return $false
        }
        if ($position -in $this.invalid_positions) {
            return $false
        }
        if ($position -le $this.depth_processed) {
            return $true
        }
        else {
            $i = $this.depth_processed
            while ($i -le $position) {
                $opcode = $this[$i]
                if ($opcode -ge [opcode_values]::PUSH1 -and $opcode -le [opcode_values]::PUSH32) {
                    $left_bound = $i + 1
                    $right_bound = $left_bound + ($opcode - 95)
                    $invalid_range = $left_bound..$right_bound
                    foreach ($p in $invalid_range) {
                        $this.invalid_positions.Add($p)
                    }
                    $i = $right_bound
                }
                else {
                    $this.depth_processed = $i
                    $i += 1
                }
            }
            if ($position -in $this.invalid_positions) {
                return $false
            }
            else {
                return $true
            }
        }
    }

    [byte] get_item([int]$index) {
        return $this.stream.GetBuffer()[$index]
    }
}
