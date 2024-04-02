using module ..\..\constants.ps1
using module ..\..\exceptions.ps1
using module ..\..\utils\numeric.ps1
using module ..\..\utils\validation.ps1

class Memory {
    [byte[]]$bytes
    [System.Object]$logger = [logging]::getLogger('evm.vm.memory.Memory')

    Memory() {
        $this.bytes = [byte[]]::new(0)
    }

    Extend([int]$start_position, [int]$size) {
        if ($size -eq 0) {
            return
        }
        $new_size = [utils.numeric]::ceil32($start_position + $size)
        if ($new_size -le $this.bytes.Length) {
            return
        }
        $size_to_extend = $new_size - $this.bytes.Length
        $this.bytes += [byte[]]::new($size_to_extend)
    }

    [int] get_length() {
        return $this.bytes.Length
    }

    write([int]$start_position, [int]$size, [byte[]]$value) {
        if ($size -gt 0) {
            [utils.validation]::validate_uint256($start_position)
            [utils.validation]::validate_uint256($size)
            [utils.validation]::validate_is_bytes($value)
            [utils.validation]::validate_length($value, $size)
            [utils.validation]::validate_lte($start_position + $size, $this.get_length())
            if ($this.bytes.Length -lt $start_position + $size) {
                $this.bytes += [byte[]]::new($this.bytes.Length - ($start_position + $size))
            }
            for ($i = 0; $i -lt $size; $i++) {
                $this.bytes[$start_position + $i] = $value[$i]
            }
        }
    }

    [byte[]] read([int]$start_position, [int]$size) {
        return $this.bytes[$start_position..($start_position + $size - 1)]
    }
}
