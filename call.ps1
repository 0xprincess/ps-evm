class CallLogic {
    [void] Call([ref] $computation) {
        $gas, $to, $value, $memoryInputStart, $memoryInputSize, $memoryOutputStart, $memoryOutputSize = $computation.Stack.Pop(7, 'uint256')
        if ($to -ne [Constants]::CREATE_CONTRACT_ADDRESS) {
            [Validation]::ValidateCanonicalAddress($to)
        }
        $computation.ExtendMemory($memoryInputStart, $memoryInputSize)
        $computation.ExtendMemory($memoryOutputStart, $memoryOutputSize)
        $callData = $computation.Memory.Read($memoryInputStart, $memoryInputSize)

        $childMsgGas, $childMsgGasFee = $this.ComputeMsgGas($computation, $gas, $to, $value)
        $computation.GasMeter.ConsumeGas($childMsgGasFee, "CALL")

        $senderBalance = $this.StateDB.GetBalance($computation.Msg.StorageAddress)
        $insufficientFunds = ($this.Msg.ShouldTransferValue -and $senderBalance -lt $value)
        $stackTooDeep = ($computation.Msg.Depth + 1 -gt [Constants]::STACK_DEPTH_LIMIT)

        if ($insufficientFunds -or $stackTooDeep) {
            if ($this.Logger) {
                if ($insufficientFunds) {
                    $errMessage = "Insufficient Funds: have: {0} | need: {1}" -f $senderBalance, $value
                } elseif ($stackTooDeep) {
                    $errMessage = "Stack Limit Reached"
                } else {
                    throw "Invariant: Unreachable code path"
                }
                $this.Logger.Debug("{0} failure: {1}", $this.Opcode.Mnemonic, $errMessage)
            }
            $computation.GasMeter.ReturnGas($childMsgGas)
            $computation.Stack.Push(0)
        } else {
            $code = if ($this.Msg.CodeAddress) { $this.StateDB.GetCode($this.Msg.CodeAddress) } else { $this.StateDB.GetCode($to) }

            $childMsgArgs = @{
                'Gas' = $childMsgGas
                'Value' = $value
                'To' = $to
                'Data' = $callData
                'Code' = $code
                'CodeAddress' = $this.Msg.CodeAddress
                'ShouldTransferValue' = $this.Msg.ShouldTransferValue
            }
            if ($this.Msg.Sender) { $childMsgArgs['Sender'] = $this.Msg.Sender }

            $childMsg = $computation.PrepareChildMessage($childMsgArgs)

            if ($childMsg.IsCreate) {
                $childComputation = $this.VM.ApplyCreateMessage($childMsg)
            } else {
                $childComputation = $this.VM.ApplyMessage($childMsg)
            }

            $computation.Children.Add($childComputation)

            if ($childComputation.Error) {
                $computation.Stack.Push(0)
            } else {
                $actualOutputSize = [Math]::Min($memoryOutputSize, $childComputation.Output.Length)
                $computation.GasMeter.ReturnGas($childComputation.GasMeter.GasRemaining)
                $computation.Memory.Write($memoryOutputStart, $actualOutputSize, $childComputation.Output[0..$actualOutputSize-1])
                $computation.Stack.Push(1)
            }
        }
    }

    [int64, int64] ComputeMsgGas([ref] $computation, [int64] $gas, [byte[]] $to, [int64] $value) {
        $accountExists = $this.StateDB.AccountExists($to)
        $transferGasFee = if ($value -gt 0) { [Constants]::GAS_CALLVALUE } else { 0 }
        $createGasFee = if (-not $accountExists) { [Constants]::GAS_NEWACCOUNT } else { 0 }
        return $transferGasFee + $createGasFee, $gas + $transferGasFee + $createGasFee
    }
}
