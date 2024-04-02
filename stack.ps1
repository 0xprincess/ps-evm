class StackLogic {
    [void] Pop([ref] $computation) {
        $computation.Stack.Pop([Constants]::ANY)
    }

    [void] PushXX([ref] $computation, [int] $size) {
        $rawValue = $computation.Code.Read($size)
        if ($rawValue.TrimEnd([byte]0).Length -eq 0) {
            $computation.Stack.Push(0)
        } else {
            $paddedValue = [byte[]]::new(32)
            [System.Buffer]::BlockCopy($rawValue, 0, $paddedValue, 0, $rawValue.Length)
            $computation.Stack.Push([System.BitConverter]::ToUInt64($paddedValue, 0))
        }
    }

    [void] Push1([ref] $computation) {
        $this.PushXX($computation, 1)
    }

    [void] Push2([ref] $computation) {
        $this.PushXX($computation, 2)
    }

    [void] Push3([ref] $computation) {
        $this.PushXX($computation, 3)
    }

    [void] Push4([ref] $computation) {
        $this.PushXX($computation, 4)
    }

    [void] Push5([ref] $computation) {
        $this.PushXX($computation, 5)
    }

    [void] Push6([ref] $computation) {
        $this.PushXX($computation, 6)
    }

    [void] Push7([ref] $computation) {
        $this.PushXX($computation, 7)
    }

    [void] Push8([ref] $computation) {
        $this.PushXX($computation, 8)
    }

    [void] Push9([ref] $computation) {
        $this.PushXX($computation, 9)
    }

    [void] Push10([ref] $computation) {
        $this.PushXX($computation, 10)
    }

    [void] Push11([ref] $computation) {
        $this.PushXX($computation, 11)
    }

    [void] Push12([ref] $computation) {
        $this.PushXX($computation, 12)
    }

    [void] Push13([ref] $computation) {
        $this.PushXX($computation, 13)
    }

    [void] Push14([ref] $computation) {
        $this.PushXX($computation, 14)
    }

    [void] Push15([ref] $computation) {
        $this.PushXX($computation, 15)
    }

    [void] Push16([ref] $computation) {
        $this.PushXX($computation, 16)
    }

    [void] Push17([ref] $computation) {
        $this.PushXX($computation, 17)
    }

    [void] Push18([ref] $computation) {
        $this.PushXX($computation, 18)
    }

    [void] Push19([ref] $computation) {
        $this.PushXX($computation, 19)
    }

    [void] Push20([ref] $computation) {
        $this.PushXX($computation, 20)
    }

    [void] Push21([ref] $computation) {
        $this.PushXX($computation, 21)
    }

    [void] Push22([ref] $computation) {
        $this.PushXX($computation, 22)
    }

    [void] Push23([ref] $computation) {
        $this.PushXX($computation, 23)
    }

    [void] Push24([ref] $computation) {
        $this.PushXX($computation, 24)
    }

    [void] Push25([ref] $computation) {
        $this.PushXX($computation, 25)
    }

    [void] Push26([ref] $computation) {
        $this.PushXX($computation, 26)
    }

    [void] Push27([ref] $computation) {
        $this.PushXX($computation, 27)
    }

    [void] Push28([ref] $computation) {
        $this.PushXX($computation, 28)
    }

    [void] Push29([ref] $computation) {
        $this.PushXX($computation, 29)
    }

    [void] Push30([ref] $computation) {
        $this.PushXX($computation, 30)
    }

    [void] Push31([ref] $computation) {
        $this.PushXX($computation, 31)
    }

    [void] Push32([ref] $computation) {
        $this.PushXX($computation, 32)
    }
}
