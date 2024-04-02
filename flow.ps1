class FlowLogic {
    [void] Stop([ref] $computation) {
        # Do nothing
    }

    [void] Jump([ref] $computation) {
        $jumpDest = $computation.Stack.Pop([Constants]::UINT256)
        $computation.Code.PC = $jumpDest
        $nextOpcode = $computation.Code.Peek()
        if ($nextOpcode -ne [OpcodeValues]::JUMPDEST) {
            throw [Exceptions.InvalidJumpDestination]::new("Invalid Jump Destination")
        }
        if (-not $computation.Code.IsValidOpcode($jumpDest)) {
            throw [Exceptions.InvalidInstruction]::new("Jump resulted in invalid instruction")
        }
    }

    [void] Jumpi([ref] $computation) {
        $jumpDest, $checkValue = $computation.Stack.Pop(2, [Constants]::UINT256)
        if ($checkValue -ne 0) {
            $computation.Code.PC = $jumpDest
            $nextOpcode = $computation.Code.Peek()
            if ($nextOpcode -ne [OpcodeValues]::JUMPDEST) {
                throw [Exceptions.InvalidJumpDestination]::new("Invalid Jump Destination")
            }
            if (-not $computation.Code.IsValidOpcode($jumpDest)) {
                throw [Exceptions.InvalidInstruction]::new("Jump resulted in invalid instruction")
            }
        }
    }

    [void] Jumpdest([ref] $computation) {
        # Do nothing
    }

    [void] Pc([ref] $computation) {
        $pc = [Math]::Max($computation.Code.PC - 1, 0)
        $computation.Stack.Push($pc)
    }

    [void] Gas([ref] $computation) {
        $computation.Stack.Push($computation.GasMeter.GasRemaining)
    }
}
