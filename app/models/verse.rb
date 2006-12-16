require 'net/http'

class Verse < ActiveRecord::Base
  has_and_belongs_to_many :people
  has_and_belongs_to_many :tags, :order => 'name'
  has_many :comments
  
  def admin?(person)
    self.people.include? person or person.admin?
  end
  
  def reference=(ref)
    write_attribute :reference, Verse.normalize_reference(ref)
    lookup
  end
  
  # living stones (KJV, ASV, YLT, AKJV, WEB)
  LS_BASE_URL = 'http://www.seek-first.com/Bible.php?q=&passage=Seek'
  
  def lookup
    return if reference.nil? or reference.empty?
    self.translation = 'WEB' if translation.nil?
    url = LS_BASE_URL + '&p=' + URI.escape(reference) + '&version=' + translation
    result = Net::HTTP.get(URI.parse(url))
    url = /<!\-\-\s*(http:\/\/api\.seek\-first\.com.+?)\s*\-\->/.match(result)[1]
    result = Net::HTTP.get(URI.parse(url)).gsub(/\s+/, ' ').gsub(/ì|î/, '"').gsub(/ë|í/, "'").gsub('*', '')
    begin
       self.text = result.scan(/<Text>(.+?)<\/Text>/).map { |p| p[0].gsub(/<.+?>/, '').strip }.join(' ')
       self.text.gsub!(/\223|\224/, '"')
       self.text.gsub!(/\221|\222/, "'")
    rescue
      nil
    end
  end
  
  def lookup!
    lookup
    save
  end
  
  def tag_string=(text)
    text.split.each do |tag_name|
      tag = Tag.find_or_create_by_name(tag_name.downcase)
      tags << tag if not tags.include? tag
    end
    tags
  end

  validates_presence_of :text, :reference
  validates_length_of :text, :maximum => 1000, :allow_nil => true, :message => " is a bit too long. Please pick a shorter passage."
  
  BOOKS = [
    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
    'Joshua',
    'Judges',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Kings',
    '2 Kings',
    '1 Chronicles',
    '2 Chronicles',
    'Ezra',
    'Nehemiah',
    'Esther',
    'Job',
    'Psalms',
    'Proverbs',
    'Ecclesiastes',
    'Song of Solomon',
    'Isaiah',
    'Jeremiah',
    'Lamentations',
    'Ezekiel',
    'Daniel',
    'Hosea',
    'Joel',
    'Amos',
    'Obadiah',
    'Jonah',
    'Micah',
    'Nahum',
    'Habakkuk',
    'Zephaniah',
    'Haggai',
    'Zechariah',
    'Malachi',
    'Matthew',
    'Mark',
    'Luke',
    'John',
    'Acts',
    'Romans',
    '1 Corinthians',
    '2 Corinthians',
    'Galatians',
    'Ephesians',
    'Philippians',
    'Colossians',
    '1 Thessalonians',
    '2 Thessalonians',
    '1 Timothy',
    '2 Timothy',
    'Titus',
    'Philemon',
    'Hebrews',
    'James',
    '1 Peter',
    '2 Peter',
    '1 John',
    '2 John',
    '3 John',
    'Jude',
    'Revelation',
  ]
  
  class << self

    # make the reference normal (proper book name, formatting, etc.)
    # we'll assume only one book per reference
    def normalize_reference(reference)
      book = normalize_book(reference.strip.downcase.match(/^.\s*[a-zA-Z]*/).to_s.strip)
      numbers = normalize_numbers(reference.gsub(/^.\s*[a-zA-Z]*/, ''))
      if book and numbers
        book + ' ' + numbers
      else
        nil
      end
    end

    def normalize_book(book)
      book.downcase!
      book.gsub(/(\d)\s*/, '\1 ') if book =~ /^\d/
      book[0..0] = '1' if book =~ /^i\s/
      book[0..0] = '2' if book =~ /^ii\s/
      book[0..0] = '3' if book =~ /^iii\s/
      if (index = BOOKS.map { |b| b.downcase }.index(book))
        BOOKS[index]
      else
        BOOKS.select { |b| b.downcase[0...book.length] == book }.first
      end
    end

    def normalize_numbers(numbers)
      numbers.gsub(/\s+/, '')
    end
    
    def combine_refs(refs)
      combined = refs.first
      refs[1..-1].each do |ref|
        if combined.index(ref.gsub(/\:.*$/, '')) == 0
          combined += ',' + /\:(.*)$/.match(ref)[1]
        elsif combined.index(ref.gsub(/\d+\:.*$/, '')) == 0
          combined += ';' + /\d+\:.*$/.match(ref)[0]
        else
          return nil # couldn't do it - fail *not* gracefully
        end
      end
      combined
    end
  end
end