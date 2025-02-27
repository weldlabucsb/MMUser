function trialNameListSorted = sortBecExpTrialName(trialNameList)
%SORTBECEXPTRIALNAME Summary of this function goes here
%   Detailed explanation goes here
nameOrder = ["Test";"Mot";"Bec"];
nameOrder = "^" + nameOrder;

trialNameList = sort(trialNameList);
orderIdx = arrayfun(@findIdx,trialNameList);
[~,idx1] = sort(orderIdx);
trialNameListSorted = trialNameList(idx1);

    function idx = findIdx(trialName)
        idx = find(~cellfun(@isempty,regexp(trialName,nameOrder)));
        if isempty(idx)
            idx = numel(nameOrder) + 1;
        end
    end

end

