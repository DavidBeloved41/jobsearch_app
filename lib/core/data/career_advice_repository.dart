class CareerArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String readTime;
  final String content;
  final String? externalUrl;

  const CareerArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.readTime,
    required this.content,
    this.externalUrl,
  });
}

class CareerAdviceRepository {
  static const articles = [
    CareerArticle(
      id: 'salary_negotiation',
      title: 'How to Negotiate Your Salary with Confidence',
      category: 'Salary',
      summary:
          'Practical strategies for researching market rates and making your case.',
      readTime: '6 min read',
      content: '''Research is your foundation. Before any conversation, use job boards, salary surveys, and your SmartJob match data to understand the range for your role, location, and experience level.

Timing matters. The best window is after a verbal offer but before you sign. Express enthusiasm first, then ask: "Is there flexibility in the compensation package?"

Anchor with data, not demands. Present a range based on market research: "Based on my research and the scope of this role, I was expecting something in the range of X to Y."

Consider the full package — base salary, bonus, equity, remote flexibility, learning budget, and title. Sometimes non-salary benefits close the gap.

Practice your script aloud. Confidence comes from preparation. Write down your key points and rehearse with a friend or mentor.''',
    ),
    CareerArticle(
      id: 'personal_branding',
      title: 'Building Your Personal Brand on LinkedIn and Beyond',
      category: 'Personal Branding',
      summary:
          'Stand out to recruiters with a consistent, authentic professional presence.',
      readTime: '5 min read',
      content: '''Your personal brand is the story people tell about you when you're not in the room. Start with clarity: what problems do you solve, for whom, and with what skills?

Optimize your headline and summary with keywords recruiters search for — but write for humans, not algorithms. Share one insight per week: a lesson learned, a project win, or an industry trend.

Consistency beats virality. Use the same professional photo, tone, and core message across SmartJob, LinkedIn, and your portfolio.

Engage authentically. Comment thoughtfully on posts in your field. Recruiters notice candidates who contribute to conversations, not just consume content.

Keep your SmartJob profile complete: skills, resume, and "Open to work" when appropriate. A strong profile increases your match scores and visibility.''',
    ),
    CareerArticle(
      id: 'remote_work_trends',
      title: 'Remote & Hybrid Work Trends in 2026',
      category: 'Workplace Trends',
      summary:
          'What candidates should know about flexible work arrangements today.',
      readTime: '4 min read',
      content: '''Remote work has stabilized into a hybrid default for many industries. Tech, marketing, and design roles lead in fully remote options; operations and healthcare remain more on-site.

When evaluating roles, look beyond the label. "Hybrid" can mean 1 day in office or 4 — clarify expectations in early conversations.

Highlight remote-ready skills on your resume: async communication, self-management, documentation, and proficiency with collaboration tools.

Use SmartJob filters for Remote, Hybrid, or On-site to match your preferences. Set your preferred work model in Edit Profile to improve your For You match scores.

Negotiate location flexibility as part of your package. Many employers will adjust arrangements for strong candidates.''',
    ),
    CareerArticle(
      id: 'ats_resume',
      title: 'Beat the ATS: Resume Formatting That Works',
      category: 'Applications',
      summary:
          'Format and keyword tips to get past applicant tracking systems.',
      readTime: '5 min read',
      content: '''Applicant Tracking Systems scan resumes for keywords from the job description. Mirror the job posting's language for skills, tools, and titles — naturally, not stuffed.

Use a clean, single-column layout. Avoid tables, text boxes, headers/footers, and graphics that parsers can't read. PDF is safe when exported from a standard editor.

Include a Skills section with both acronyms and spelled-out terms (e.g., "AI (Artificial Intelligence)").

Quantify achievements: "Increased application conversion by 23%" beats "Improved conversion."

Use SmartJob's ATS check on your resume draft against specific jobs to find missing keywords before you apply.''',
    ),
    CareerArticle(
      id: 'interview_prep',
      title: 'STAR Method for Behavioral Interviews',
      category: 'Interviews',
      summary:
          'Structure compelling answers using Situation, Task, Action, Result.',
      readTime: '4 min read',
      content: '''Behavioral questions ("Tell me about a time when...") test how you've handled real situations. The STAR method keeps answers focused:

Situation — Set the scene briefly (1-2 sentences).
Task — What was your responsibility?
Action — What did YOU do specifically? Use "I" not "we."
Result — Quantify the outcome when possible.

Prepare 5-6 stories covering leadership, conflict, failure, success, teamwork, and learning. Map them to common question types.

Practice aloud until stories feel conversational, not memorized. Aim for 90 seconds per answer.

After each interview round, jot notes while fresh. You'll improve faster and can reference details in thank-you follow-ups.''',
    ),
    CareerArticle(
      id: 'skill_growth',
      title: 'Closing Skill Gaps Without Going Back to School',
      category: 'Career Growth',
      summary:
          'Affordable ways to build in-demand skills recruiters want.',
      readTime: '5 min read',
      content: '''Start with SmartJob's Skill Gap Analysis — it shows which skills appear most in jobs matching your target roles.

Micro-learning wins: 30 minutes daily on focused tutorials beats occasional marathon sessions. Build one small project per skill to prove capability.

Free and low-cost resources: official documentation, YouTube deep-dives, Coursera audit tracks, and LinkedIn Learning trials.

Certifications help for regulated fields; for tech, portfolios and GitHub often matter more. Show don't tell.

Add new skills to your SmartJob profile as you learn. Your match scores update immediately, surfacing better job recommendations.''',
    ),
  ];

  static List<CareerArticle> byCategory(String category) {
    return articles.where((a) => a.category == category).toList();
  }

  static List<String> get categories {
    return articles.map((a) => a.category).toSet().toList()..sort();
  }

  static CareerArticle? findById(String id) {
    try {
      return articles.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
