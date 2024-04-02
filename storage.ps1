class StorageLogic {
    [void] Sstore([ref] $computation) {
        $slot, $value = $computation.Stack.Pop(2, [Constants]::UINT256)
        $currentValue = $this.StateDB.GetStorage($computation.Msg.StorageAddress, $slot)
        $isCurrentlyEmpty = $currentValue -eq 0
        $isGoingToBeEmpty = $value -eq 0

        if ($isCurrentlyEmpty) {
            $gasRefund = 0
        } elseif ($isGoingToBeEmpty) {
            $gasRefund = [Constants]::REFUND_SCLEAR
        } else {
            $gasRefund = 0
        }

        if ($isCurrentlyEmpty -and $isGoingToBeEmpty) {
            $gasCost = [Constants]::GAS_SRESET
        } elseif ($isCurrentlyEmpty) {
            $gasCost = [Constants]::GAS_SSET
        } elseif ($isGoingToBeEmpty) {
            $gasCost = [Constants]::GAS_SRESET
        } else {
            $gasCost = [Constants]::GAS_SRESET
        }

        $computation.GasMeter.ConsumeGas($gasCost, "SSTORE: {0}[{1}] -> {2} ({3})" -f $computation.Msg.StorageAddress, $slot, $value, $currentValue)

        if ($gasRefund -gt 0) {
            $computation.GasMeter.RefundGas($gasRefund)
        }

        $this.StateDB.SetStorage($computation.Msg.StorageAddress, $slot, $value)
    }

    [void] Sload([ref] $computation) {
        $slot = $computation.Stack.Pop([Constants]::UINT256)
        $value = $this.StateDB.GetStorage($computation.Msg.StorageAddress, $slot)
        $computation.Stack.Push($value)
    }
}
