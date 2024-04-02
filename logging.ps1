class LoggingLogic {
    [void] Log([ref] $computation, [int] $topicCount) {
        if ($topicCount -lt 0 -or $topicCount -gt 4) {
            throw [ArgumentException]::new("Invalid log topic size. Must be 0, 1, 2, 3, or 4")
        }

        $memStart, $size = $computation.Stack.Pop(2, [Constants]::UINT256)
        $topics = if ($topicCount -gt 0) { $computation.Stack.Pop($topicCount, [Constants]::UINT256) } else { @() }

        $dataGasCost = [Constants]::GAS_LOGDATA * $size
        $topicGasCost = [Constants]::GAS_LOGTOPIC * $topicCount
        $totalGasCost = $dataGasCost + $topicGasCost

        $computation.GasMeter.ConsumeGas($totalGasCost, "Log topic and data gas cost")

        $computation.ExtendMemory($memStart, $size)
        $logData = $computation.Memory.Read($memStart, $size)

        $computation.AddLogEntry($computation.Msg.StorageAddress, $topics, $logData)
    }

    [void] Log0([ref] $computation) {
        $this.Log($computation, 0)
    }

    [void] Log1([ref] $computation) {
        $this.Log($computation, 1)
    }

    [void] Log2([ref] $computation) {
        $this.Log($computation, 2)
    }

    [void] Log3([ref] $computation) {
        $this.Log($computation, 3)
    }

    [void] Log4([ref] $computation) {
        $this.Log($computation, 4)
    }
}
