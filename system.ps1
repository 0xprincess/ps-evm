class SystemLogic {
    [void] Return([ref] $computation) {
        $start, $size = $computation.Stack.Pop(2, [Constants]::UINT256)
        $computation.ExtendMemory($start, $size)
        $computation.Output = $computation.Memory.Read($start, $size)
    }

    [void] Suicide([ref] $computation) {
        $beneficiary = $computation.Stack.Pop([Constants]::BYTES)
        $this.Suicide($computation, $beneficiary)
    }

    [void] SuicideEIP150([ref] $computation) {
        $beneficiary = $computation.Stack.Pop([Constants]::BYTES)
        if (-not $this.StateDB.AccountExists($beneficiary)) {
            $computation.GasMeter.ConsumeGas([Constants]::GAS_SUICIDE_NEWACCOUNT, "SUICIDE")
        }
        $this.Suicide($computation, $beneficiary)
    }

    [void] Suicide([ref] $computation, [byte[]] $beneficiary) {
        $localBalance = $this.StateDB.GetBalance($computation.Msg.StorageAddress)
        $beneficiaryBalance = $this.StateDB.GetBalance($beneficiary)

        # 1. Transfer to beneficiary
        $this.StateDB.SetBalance($beneficiary, $localBalance + $beneficiaryBalance)

        # 2. Zero the balance of the address being deleted
        $this.StateDB.SetBalance($computation.Msg.StorageAddress, 0)

        # 3. Register the account to be deleted
        $computation.RegisterAccountForDeletion($computation.Msg.StorageAddress)
    }

    [void] Create([ref] $computation) {
        $computation.GasMeter.ConsumeGas($this.Opcode.GasCost, $this.Opcode.Mnemonic)
        $value, $start, $size = $computation.Stack.Pop(3, [Constants]::UINT256)
        $computation.ExtendMemory($start, $size)
        $insufficientFunds = $this.StateDB.GetBalance($computation.Msg.StorageAddress) -lt $value
        $stackTooDeep = $computation.Msg.Depth + 1 -gt [Constants]::STACK_DEPTH_LIMIT
        if ($insufficientFunds -or $stackTooDeep) {
            $computation.Stack.Push(0)
            return
        }
        $createData = $computation.Memory.Read($start, $size)
        $createMsgGas = $this.GetMaxChildGasModifier($computation.GasMeter.GasRemaining)
        $computation.GasMeter.ConsumeGas($createMsgGas, "CREATE")
        $creationNonce = $this.StateDB.GetNonce($computation.Msg.StorageAddress)
        $contractAddress = $this.GenerateContractAddress($computation.Msg.StorageAddress, $creationNonce)
        $childMsg = $computation.PrepareChildMessage(
            'Gas' = $createMsgGas,
            'To' = [Constants]::CREATE_CONTRACT_ADDRESS,
            'Value' = $value,
            'Data' = [byte[]]::new(0),
            'Code' = $createData,
            'CreateAddress' = $contractAddress
        )
        if ($childMsg.IsCreate) {
            $childComputation = $this.VM.ApplyCreateMessage($childMsg)
        } else {
            $childComputation = $this.VM.ApplyMessage($childMsg)
        }
        $computation.Children.Add($childComputation)
        if ($childComputation.Error) {
            $computation.Stack.Push(0)
        } else {
            $computation.GasMeter.ReturnGas($childComputation.GasMeter.GasRemaining)
            $computation.Stack.Push($contractAddress)
        }
    }

    [int64] GetMaxChildGasModifier([int64] $gas) {
        return [Math]::Max(0, $gas - [Math]::Ceiling($gas / [Constants]::GAS_CALL_STIPEND_DENOMINATOR))
    }

    [byte[]] GenerateContractAddress([byte[]] $address, [int64] $nonce) {
        return [System.Security.Cryptography.SHA256]::Create().ComputeHash([byte[]]($address + [BitConverter]::GetBytes($nonce)))[-20..-1]
    }
}
