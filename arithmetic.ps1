class Arithmetic {
   [void] Add([ref] $computation) {
       $left, $right = $computation.Stack.Pop(2, 'uint256')
       $result = ($left + $right) -band [uint64]::MaxValue
       $computation.Stack.Push($result)
   }

   [void] Addmod([ref] $computation) {
       $left, $right, $mod = $computation.Stack.Pop(3, 'uint256')
       if ($mod -eq 0) {
           $result = 0
       } else {
           $result = (($left + $right) -band [uint64]::MaxValue) -band $mod
       }
       $computation.Stack.Push($result)
   }

   [void] Sub([ref] $computation) {
       $left, $right = $computation.Stack.Pop(2, 'uint256')
       $result = ($left - $right) -band [uint64]::MaxValue
       $computation.Stack.Push($result)
   }

   [void] Mod([ref] $computation) {
       $value, $mod = $computation.Stack.Pop(2, 'uint256')
       if ($mod -eq 0) {
           $result = 0
       } else {
           $result = $value -band $mod
       }
       $computation.Stack.Push($result)
   }

   [void] Smod([ref] $computation) {
       $value, $mod = $computation.Stack.Pop(2, 'uint256')
       $sign = if ($value -lt 0) { -1 } else { 1 }
       if ($mod -eq 0) {
           $result = 0
       } else {
           $result = ([Math]::Abs($value) -band ([Math]::Abs($mod) - 1)) * $sign -band [uint64]::MaxValue
       }
       $computation.Stack.Push($result)
   }

   [void] Mul([ref] $computation) {
       $left, $right = $computation.Stack.Pop(2, 'uint256')
       $result = ($left * $right) -band [uint64]::MaxValue
       $computation.Stack.Push($result)
   }

   [void] Mulmod([ref] $computation) {
       $left, $right, $mod = $computation.Stack.Pop(3, 'uint256')
       if ($mod -eq 0) {
           $result = 0
       } else {
           $result = (($left * $right) -band [uint64]::MaxValue) -band $mod
       }
       $computation.Stack.Push($result)
   }

   [void] Div([ref] $computation) {
       $numerator, $denominator = $computation.Stack.Pop(2, 'uint256')
       if ($denominator -eq 0) {
           $result = 0
       } else {
           $result = [System.Numerics.BigInteger]::DivRem($numerator, $denominator, [System.Numerics.BigInteger]::Zero) -band [uint64]::MaxValue
       }
       $computation.Stack.Push($result)
   }

   [void] Sdiv([ref] $computation) {
       $numerator, $denominator = $computation.Stack.Pop(2, 'uint256')
       $sign = if (($numerator * $denominator) -lt 0) { -1 } else { 1 }
       if ($denominator -eq 0) {
           $result = 0
       } else {
           $result = [Math]::Floor([Math]::Abs($numerator) / [Math]::Abs($denominator)) * $sign -band [uint64]::MaxValue
       }
       $computation.Stack.Push($result)
   }

   [void] Exp([ref] $computation) {
       $base, $exponent = $computation.Stack.Pop(2, 'uint256')
       $bitSize = [Math]::Ceiling([Math]::Log($exponent, 2))
       $byteSize = [Math]::Ceiling($bitSize / 8)
       if ($base -eq 0) {
           $result = 0
       } else {
           $result = [System.Numerics.BigInteger]::ModPow($base, $exponent, [System.Numerics.BigInteger]::MaxValue)
       }
       $computation.GasMeter.ConsumeGas($byteSize * [Constants]::GAS_EXPBYTE, "EXP: exponent bytes")
       $computation.Stack.Push($result)
   }

   [void] Signextend([ref] $computation) {
       $bits, $value = $computation.Stack.Pop(2, 'uint256')
       if ($bits -le 31) {
           $testBit = $bits * 8 + 7
           $signBit = 1 -shl $testBit
           if (($value -band $signBit) -gt 0) {
               $result = $value -bor ([uint64]::MaxValue - $signBit + 1)
           } else {
               $result = $value -band ($signBit - 1)
           }
       } else {
           $result = $value
       }
       $computation.Stack.Push($result)
   }
}
