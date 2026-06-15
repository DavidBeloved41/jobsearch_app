class ResumeTemplate {
  final String id;
  final String name;
  final String description;
  final String content;

  const ResumeTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.content,
  });
}

class CoverLetterTemplate {
  final String id;
  final String name;
  final String content;

  const CoverLetterTemplate({
    required this.id,
    required this.name,
    required this.content,
  });
}

class ResumeTemplates {
  static const templates = [
    ResumeTemplate(
      id: 'professional',
      name: 'Professional Summary',
      description: 'Clean summary for experienced professionals',
      content: '''PROFESSIONAL SUMMARY
Results-driven [Job Title] with [X] years of experience in [Industry/Domain]. Proven track record of delivering high-impact projects, collaborating with cross-functional teams, and driving measurable business outcomes.

CORE COMPETENCIES
• [Skill 1] • [Skill 2] • [Skill 3] • [Skill 4]

EXPERIENCE
[Company Name] — [Job Title] | [Dates]
• Led [project/initiative] resulting in [quantifiable outcome]
• Collaborated with [teams/stakeholders] to [achievement]
• Improved [metric/process] by [percentage/amount]

EDUCATION
[Degree], [University] | [Year]''',
    ),
    ResumeTemplate(
      id: 'tech',
      name: 'Tech / Engineering',
      description: 'Highlights technical skills and projects',
      content: '''[Your Name] — [Job Title]
[Email] | [Phone] | [Location] | [LinkedIn/GitHub]

TECHNICAL SKILLS
Languages: [e.g. Dart, Python, JavaScript]
Frameworks: [e.g. Flutter, React, Node.js]
Tools: [e.g. Git, Docker, AWS, Supabase]

EXPERIENCE
[Company] — [Role] | [Dates]
• Built [feature/system] using [tech stack], serving [users/scale]
• Reduced [metric] by [X]% through [approach]
• Mentored [N] engineers on [topic]

PROJECTS
[Project Name] — [Brief description and tech used]

EDUCATION
[Degree] in [Field], [University]''',
    ),
    ResumeTemplate(
      id: 'career_change',
      name: 'Career Change',
      description: 'Emphasizes transferable skills',
      content: '''PROFESSIONAL PROFILE
Motivated professional transitioning into [Target Role] with transferable skills in [areas]. Combines [previous domain] experience with recent training in [new skills].

TRANSFERABLE SKILLS
• Problem solving & analytical thinking
• Communication & stakeholder management
• [Skill relevant to target role]

RELEVANT EXPERIENCE
[Previous Role] — [Company] | [Dates]
• [Achievement showing transferable skill]
• [Achievement with measurable impact]

RECENT DEVELOPMENT
• [Course/Certification/Project related to target role]
• [Self-directed learning or portfolio project]''',
    ),
  ];

  static const coverLetters = [
    CoverLetterTemplate(
      id: 'standard',
      name: 'Standard Application',
      content: '''Dear Hiring Manager,

I am excited to apply for the [Job Title] position at [Company Name]. With my background in [your field] and experience in [key skill/area], I am confident I can contribute effectively to your team.

In my previous role at [Previous Company], I [key achievement with metric]. I am particularly drawn to [Company Name] because of [specific reason about company/mission].

I would welcome the opportunity to discuss how my skills align with your needs. Thank you for your consideration.

Best regards,
[Your Name]''',
    ),
    CoverLetterTemplate(
      id: 'enthusiastic',
      name: 'High Enthusiasm',
      content: '''Dear [Hiring Manager Name / Hiring Team],

When I saw the opening for [Job Title] at [Company Name], I knew immediately this was the role I've been looking for. Your focus on [company value/product/mission] resonates strongly with my career goals.

My experience includes [2-3 relevant highlights]. I thrive in [work environment e.g. fast-paced, collaborative] settings and am eager to bring that energy to your team.

I look forward to the possibility of contributing to [Company Name]'s continued success.

Warm regards,
[Your Name]''',
    ),
    CoverLetterTemplate(
      id: 'referral',
      name: 'Referral / Network',
      content: '''Dear Hiring Manager,

I was referred to the [Job Title] position at [Company Name] by [Referrer Name], who spoke highly of your team culture and the impact of this role.

With [X] years of experience in [domain] and a strong foundation in [skills], I believe I would be a valuable addition. [One specific achievement relevant to the role.]

Thank you for your time and consideration. I hope to discuss this opportunity further.

Sincerely,
[Your Name]''',
    ),
  ];
}
