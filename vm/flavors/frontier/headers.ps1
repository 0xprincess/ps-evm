using module ..\..\..\constants.ps1
using module ..\..\..\exceptions.ps1
using module ..\..\..\rlp\headers.ps1
using module ..\..\..\utils\headers.ps1

function create_frontier_header_from_parent([BlockHeader]$parent_header, [hashtable]$header_params = @{}) {
    if (-not $header_params.ContainsKey("difficulty")) {
        $header_params["timestamp"] = $parent_header.timestamp + 1
        $header_params["difficulty"] = compute_frontier_difficulty($parent_header, $header_params["timestamp"])
    }
    if (-not $header_params.ContainsKey("gas_limit")) {
        $header_params["gas_limit"] = compute_gas_limit($parent_header, [constants]::GENESIS_GAS_LIMIT)
    }
    $header = [BlockHeader]::FromParent($parent_header, $header_params)
    return $header
}

function compute_frontier_difficulty([BlockHeader]$parent_header, [int]$timestamp) {
    [utils.validation]::validate_gt($timestamp, $parent_header.timestamp)
    $offset = $parent_header.difficulty / [constants]::DIFFICULTY_ADJUSTMENT_DENOMINATOR
    $difficulty_minimum = [Math]::Max($parent_header.difficulty, [constants]::DIFFICULTY_MINIMUM)
    if ($timestamp - $parent_header.timestamp -lt [constants]::FRONTIER_DIFFICULTY_ADJUSTMENT_CUTOFF) {
        $base_difficulty = [Math]::Max($parent_header.difficulty + $offset, $difficulty_minimum)
    }
    else {
        $base_difficulty = [Math]::Max($parent_header.difficulty - $offset, $difficulty_minimum)
    }
    $num_bomb_periods = ($parent_header.block_number + 1) / [constants]::BOMB_EXPONENTIAL_PERIOD - [constants]::BOMB_EXPONENTIAL_FREE_PERIODS
    if ($num_bomb_periods -ge 0) {
        $difficulty = [Math]::Max($base_difficulty + [Math]::Pow(2, $num_bomb_periods), [constants]::DIFFICULTY_MINIMUM)
    }
    else {
        $difficulty = $base_difficulty
    }
    return $difficulty
}

function configure_frontier_header([VM]$vm, [hashtable]$header_params = @{}) {
    $extra_fields = [System.Collections.Generic.HashSet[string]]::new($header_params.Keys) - [System.Collections.Generic.HashSet[string]]::new((
        "coinbase",
        "gas_limit",
        "timestamp",
        "extra_data",
        "mix_hash",
        "nonce"
    ))
    if ($extra_fields.Count -gt 0) {
        throw [System.ValueError]::new("The `configure_header` method may only be used with the fields (coinbase, gas_limit, timestamp, extra_data, mix_hash, nonce). The provided fields ($([string]::Join(', ', $extra_fields.ToArray()))) are not supported")
    }
    foreach ($key in $header_params.Keys) {
        $vm.block.header.$key = $header_params[$key]
    }
    if ("timestamp" -in $header_params.Keys -and $vm.block.header.block_number -gt 0) {
        $parent_header = $vm.block.GetParentHeader()
        $vm.block.header.difficulty = compute_frontier_difficulty($parent_header, $header_params["timestamp"])
    }
    return $vm.block.header
}
