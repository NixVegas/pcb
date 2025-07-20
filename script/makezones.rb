#!/usr/bin/env ruby

require 'securerandom'

template = <<EOF
(zone
      (net 0)
      (net_name "")
      (layer "B.Cu")
      (uuid "%1$s")
      (name "ART")
      (hatch full 0.5)
      (connect_pads
              (clearance 0)
      )
      (min_thickness 0.25)
      (filled_areas_thickness no)
      (keepout
              (tracks not_allowed)
              (vias not_allowed)
              (pads not_allowed)
              (copperpour not_allowed)
              (footprints not_allowed)
      )
      (placement
              (enabled no)
              (sheetname "/")
      )
      (fill
              (mode hatch)
              (thermal_gap 0.5)
              (thermal_bridge_width 0.5)
              (island_removal_mode 1)
              (island_area_min 10)
              (hatch_thickness 0.25)
              (hatch_gap 1)
              (hatch_orientation -60)
              (hatch_smoothing_level 2)
              (hatch_smoothing_value 0.1)
              (hatch_border_algorithm hatch_thickness)
              (hatch_min_hole_area 0.3)
      )
      (polygon
          %2$s
)
EOF

project = File.read(ARGV.first)
zones = []
project.gsub(%r[\(fp_poly (.+?^\s+\)$)]m) do |m|
  ret = template % [SecureRandom.uuid, $~[1]]
  ret.gsub! /\(layer\s+[^)]+\)\s*\(width\s+[^)]+\)/, ''
  zones << ret
  ret
end

puts zones.join("\n")
