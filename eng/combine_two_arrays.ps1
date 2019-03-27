set-alias ?@@ Apply-ArrayOperation #http://stackoverflow.com/a/29758367/361842
function Apply-ArrayOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [object[]]$Left
        ,
        [Parameter(Mandatory,ParameterSetName='exclude', Position=1)]
        [switch]$exclude
        ,
        [Parameter(Mandatory,ParameterSetName='intersect', Position=1)]
        [switch]$intersect
        ,
        [Parameter(Mandatory,ParameterSetName='outersect', Position=1)] #not sure what the correct term for this is
        [switch]$outersect
        ,
        [Parameter(Mandatory,ParameterSetName='union', Position=1)] #not sure what the correct term for this is
        [switch]$union
        ,
        [Parameter(Mandatory,ParameterSetName='unionAll', Position=1)] #not sure what the correct term for this is
        [switch]$unionAll
        ,
        [Parameter(Mandatory, Position=2)]
        [object[]]$Right
    )
    begin {
        #doing this way so we can use a switch staement below, whilst having [switch] syntax for the function's caller 
        [int]$action = 1*$exclude.IsPresent + 2*$intersect.IsPresent + 3*$outersect.IsPresent + 4*$union.IsPresent + 5*$unionAll.IsPresent
    }
    process {
        switch($action) {
            1 {$Left | ?{$Right -notcontains $_}} 
            2 {$Left | ?{$Right -contains $_} }
            3 {@($Left | ?{$Right -notcontains $_}) + @($Right | ?{$Left -notcontains $_})}       
            4 {@($Left) + @($Right) | select -Unique}       
            5 {@($Left) + @($Right)}       
        }
    }
}

$array1 = @(1,3,5,7,9)
$array2 = @(2,3,4,5,6,7)

"Array 1"; $array1
"Array 1"; $array2

"Array 1 Exclude Array 2";   ?@@ $array1 -exclude $array2 
"Array 1 Intersect Array 2"; ?@@ $array1 -intersect $array2
"Array 1 Outersect Array 2"; ?@@ $array1 -outersect $array2
"Array 1 Union Array 2";     ?@@ $array1 -union $array2
"Array 1 UnionAll Array 2";  ?@@ $array1 -unionall $array2