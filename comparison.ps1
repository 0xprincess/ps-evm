class Comparison {
    [void] Lt([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        if ($left -lt $right) {
            $result = 1
        } else {
            $result = 0
        }
        $computation.Stack.Push($result)
    }

    [void] Gt([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        if ($left -gt $right) {
            $result = 1
        } else {
            $result = 0
        }
        $computation.Stack.Push($result)
    }

    [void] Slt([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        $left = $this.UnsignedToSigned($left)
        $right = $this.UnsignedToSigned($right)
        if ($left -lt $right) {
            $result = 1
        } else {
            $result = 0
        }
        $computation.Stack.Push($this.SignedToUnsigned($result))
    }

    [void] Sgt([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        $left = $this.UnsignedToSigned($left)
        $right = $this.UnsignedToSigned($right)
        if ($left -gt $right) {
            $result = 1
        } else {
            $result = 0
        }
        $computation.Stack.Push($this.SignedToUnsigned($result))
    }

    [void] Eq([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        if ($left -eq $right) {
            $result = 1
        } else {
            $result = 0
        }
        $computation.Stack.Push($result)
    }

    [void] Iszero([ref] $computation) {
        $value = $computation.Stack.Pop('uint256')
        if ($value -eq 0) {
            $result = 1
        } else {
            $result = 0
        }
        $computation.Stack.Push($result)
    }

    [void] And([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        $result = $left -band $right
        $computation.Stack.Push($result)
    }

    [void] Or([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        $result = $left -bor $right
        $computation.Stack.Push($result)
    }

    [void] Xor([ref] $computation) {
        $left, $right = $computation.Stack.Pop(2, 'uint256')
        $result = $left -bxor $right
        $computation.Stack.Push($result)
    }

    [void] Not([ref] $computation) {
        $value = $computation.Stack.Pop('uint256')
        $result = [uint64]::MaxValue - $value
        $computation.Stack.Push($result)
    }

    [void] Byte([ref] $computation) {
        $position, $value = $computation.Stack.Pop(2, 'uint256')
        if ($position -ge 32) {
            $result = 0
        } else {
            $result = ($value -shr (($position -band 31) * 8)) -band 0xFF
        }
        $computation.Stack.Push($result)
    }

    [int64] UnsignedToSigned([int64] $value) {
        if ($value -le [Constants]::UINT_255_MAX) {
            return $value
        } else {
            return $value - [Constants]::UINT_256_CEILING
        }
    }

    [int64] SignedToUnsigned([int64] $value) {
        if ($value -lt 0) {
            return $value + [Constants]::UINT_256_CEILING
        } else {
            return $value
        }
    }
}
