class BlockLogic {
    [void] Blockhash([ref] $computation) {
        $blockNumber = $computation.Stack.Pop('uint256')
        $blockHash = $this.VM.GetAncestorHash($blockNumber)
        $computation.Stack.Push($blockHash)
    }

    [void] Coinbase([ref] $computation) {
        $computation.Stack.Push($this.VM.Block.Header.Coinbase)
    }

    [void] Timestamp([ref] $computation) {
        $computation.Stack.Push($this.VM.Block.Header.Timestamp)
    }

    [void] Number([ref] $computation) {
        $computation.Stack.Push($this.VM.Block.Header.BlockNumber)
    }

    [void] Difficulty([ref] $computation) {
        $computation.Stack.Push($this.VM.Block.Header.Difficulty)
    }

    [void] Gaslimit([ref] $computation) {
        $computation.Stack.Push($this.VM.Block.Header.GasLimit)
    }
}
