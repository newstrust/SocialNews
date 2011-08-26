module SubjectsHelper
  def subject_title_and_meta_info(subject)
    subject_desc = subject.name
    title = subject.name + " News"
    if subject.name == "World" || subject.name == "U.S."
      subject_desc = "the " + subject.name
    elsif subject.name == "Politics"
      title = "Political News"
    elsif subject.name == "Sci/Tech"
      title = "Science & Technology News"
      subject_desc = "Science & Technology"
    end
    meta_keywords    = title
    meta_description = "News stories posted to #{SocialNewsConfig["app"]["name"]} on the subject of #{subject_desc}."

    [title, meta_keywords, meta_description]
  end
end
