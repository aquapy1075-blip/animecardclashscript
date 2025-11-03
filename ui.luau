function Tab:AddDivider()
    local Divider = Instance.new("Frame")
    Divider.Name = "Divider"
    Divider.Size = UDim2.new(1, -10, 0, 1)
    Divider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    Divider.BackgroundTransparency = 0.6
    Divider.BorderSizePixel = 0
    Divider.Position = UDim2.new(0, 5, 0, 0)
    Divider.Parent = self.TabSection or self.Page or self.Container or self.Section or self.Content or self.Holder
    Divider.ZIndex = 2

    -- Thêm một khoảng cách nhỏ phía trên/dưới
    local Padding = Instance.new("Frame")
    Padding.Size = UDim2.new(1, 0, 0, 4)
    Padding.BackgroundTransparency = 1
    Padding.Parent = Divider.Parent

    return Divider
end
