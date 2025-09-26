trigger UpdateChildAssetAccount on Asset (before insert, before update) {
    Set<Id> parentAssetIds = new Set<Id>();

    for (Asset asset : Trigger.new) {
        if (asset.ParentId != null) {
            parentAssetIds.add(asset.ParentId);
        }
    }

    if (parentAssetIds.isEmpty()) return;

    // Query parent assets with AccountId
    Map<Id, Asset> parentAssets = new Map<Id, Asset>(
        [SELECT Id, AccountId FROM Asset WHERE Id IN :parentAssetIds]
    );

    for (Asset asset : Trigger.new) {
        if (asset.ParentId != null && parentAssets.containsKey(asset.ParentId)) {
            asset.AccountId = parentAssets.get(asset.ParentId).AccountId;
        }
    }
}