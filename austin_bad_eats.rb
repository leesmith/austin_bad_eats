#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'csv'
require 'open-uri'

puts "========== #{Time.now} Start =========="
DOC_ROOT = 'http://www.ci.austin.tx.us/health/restaurant/scores.cfm'
MINIMUM_INSPECTION_SCORE = 70

# Define inspection struct
InspectionReport = Struct.new(:establishment, :address, :city, :zip, :inspection_date, :score) do
  def to_a
    [establishment, address, city, zip, inspection_date, score]
  end

  def to_tweet
    "#{establishment} scored #{score} on #{inspection_date}"
  end

  def to_s
    "#{score} :: #{inspection_date} :: #{establishment}"
  end
end

# build inspection history
inspection_history = []
CSV.foreach('history.csv') do |row|
  establishment = row[0]
  address = row[1]
  city = row[2]
  zip = row[3]
  inspection_date = Date.strptime(row[4], '%Y-%m-%d')
  score = row[5].to_i
  inspection_history << InspectionReport.new(establishment, address, city, zip, inspection_date, score)
end

beg_date = (Date.today - 30).strftime('%d-%b-%Y')
end_date = Date.today.strftime('%d-%b-%Y')
search_params="?submit=search&orderby=3&begdate=#{beg_date}&enddate=#{end_date}&estabcity=All&estabname=&selpara=0&estabzip=All"
doc = Nokogiri::HTML(open(DOC_ROOT + search_params))
score_table = doc.search("table")
rows = score_table.search('tr')

inspections = []
rows.each_with_index do |tr, i|
  # skip header row
  next if i == 0

  establishment = tr.children[1].text.strip
  address = tr.children[3].text.strip
  city = tr.children[5].text.strip
  zip = tr.children[7].text.strip
  inspection_date = Date.strptime(tr.children[9].text, '%m/%d/%Y')
  score = tr.children[11].text.to_i
  inspections << InspectionReport.new(establishment, address, city, zip, inspection_date, score)
end

# sort in ascending order
inspections.sort! { |a,b| a.inspection_date <=> b.inspection_date }

# tweet sub-70 inspections
sub_70_inspections = []
inspections.each do |inspection|
  if (!inspection_history.include?(inspection)) && (inspection.score < MINIMUM_INSPECTION_SCORE)
    sub_70_inspections << inspection
    puts inspection.to_s

    # specify twitter acount to use
    cmd = "t set active austin_bad_eats"
    system(cmd)

    # post tweet
    cmd = "t update \"#{inspection.to_tweet}\""
    puts cmd
    system(cmd)
  end
end

# write sub_70_inspections to history
if sub_70_inspections.count > 0
  CSV.open('history.csv','a+') do |csv|
    sub_70_inspections.each do |hit|
      csv << hit.to_a
    end
  end
end

puts "========== #{Time.now} Done! =========="
exit 0
