# frozen_string_literal: true

# 点がポリゴン内にあるかを判定するモジュール
# Ray Casting Algorithm を実装
# d3-geo の geoContains に相当
module PbfReverseGeocoder
  class PointInPolygon

    # 点がポリゴン内にあるか判定
    # 点からX軸正方向に伸ばした半直線が、ポリゴンの辺と何回交差するかを数える
    # 奇数回 = 内側、偶数回 = 外側
    #
    # @param point [Array<Float>] [lng, lat] 判定する点の座標
    # @param polygon [Array<Array<Float>>] [[lng, lat], ...] ポリゴンの頂点座標配列
    # @return [Boolean] true: 内側, false: 外側
    def self.contains?(point, polygon)
      return false if polygon.nil? || polygon.empty?

      px, py = point
      inside = false

      # ポリゴンの各辺について交差判定
      j = polygon.length - 1
      polygon.length.times do |i|
        xi, yi = polygon[i]
        xj, yj = polygon[j]

        # Y座標の範囲チェック:辺が点のY座標をまたいでいるか
        if (yi > py) != (yj > py)
          # X座標の交差判定:半直線が辺と交差する点のX座標を計算
          x_intersect = ((xj - xi) * (py - yi) / (yj - yi)) + xi

          # 点のX座標より右側で交差していたら、inside を反転
          inside = !inside if px < x_intersect
        end

        j = i
      end

      inside
    end

  end
end
