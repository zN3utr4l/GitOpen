using GitOpen.Domain.Refs;

namespace GitOpen.Ui.Components;

public sealed class BranchTreeNode
{
    public required string Name { get; init; }
    public required string FullPath { get; init; }
    public Branch? Branch { get; init; }
    public List<BranchTreeNode> Children { get; } = new();
    public bool IsLeaf => Branch is not null && Children.Count == 0;
}

public static class BranchTree
{
    public static List<BranchTreeNode> Build(IEnumerable<Branch> branches)
    {
        var roots = new List<BranchTreeNode>();
        var lookup = new Dictionary<string, BranchTreeNode>(StringComparer.Ordinal);

        foreach (var branch in branches)
        {
            var parts = branch.Name.Split('/');
            BranchTreeNode? parent = null;
            var currentPath = string.Empty;

            for (var i = 0; i < parts.Length; i++)
            {
                currentPath = i == 0 ? parts[0] : $"{currentPath}/{parts[i]}";
                var isLast = i == parts.Length - 1;

                if (!lookup.TryGetValue(currentPath, out var node))
                {
                    node = new BranchTreeNode
                    {
                        Name = parts[i],
                        FullPath = currentPath,
                        Branch = isLast ? branch : null
                    };
                    lookup[currentPath] = node;
                    if (parent is null) roots.Add(node);
                    else parent.Children.Add(node);
                }
                parent = node;
            }
        }

        SortRecursive(roots);
        return roots;
    }

    private static void SortRecursive(List<BranchTreeNode> nodes)
    {
        nodes.Sort((a, b) =>
        {
            var aIsFolder = a.Children.Count > 0;
            var bIsFolder = b.Children.Count > 0;
            if (aIsFolder != bIsFolder) return aIsFolder ? -1 : 1;
            return string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
        });
        foreach (var n in nodes) SortRecursive(n.Children);
    }

    public static IEnumerable<string> AllFolderPaths(IEnumerable<BranchTreeNode> nodes)
    {
        foreach (var n in nodes)
        {
            if (n.Children.Count > 0)
            {
                yield return n.FullPath;
                foreach (var sub in AllFolderPaths(n.Children)) yield return sub;
            }
        }
    }
}
