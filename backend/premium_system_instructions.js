/**
 * PREMIUM AI SYSTEM INSTRUCTIONS - USER-ORIENTED EDUCATIONAL COMPANION
 * Enhanced version that creates specific, curriculum-focused instructions based on user input
 */

function generatePremiumSystemInstructions(
  botName,
  botTopic,
  description,
  gradeLevel,
) {
  // Extract key learning objectives from user description
  const learningObjectives = extractLearningObjectives(description);
  const curriculumFocus = generateCurriculumFocus(
    botTopic,
    gradeLevel,
    description,
  );
  const teachingApproach = adaptTeachingApproach(gradeLevel);
  const specificTopics = generateSpecificTopics(
    botTopic,
    description,
    gradeLevel,
  );

  const instructions = `## 🌟 YOU ARE "${botName}" - YOUR PERSONALIZED STUDY COMPANION

You are "${botName}", a specialized AI tutor created specifically to help students master **${botTopic}** at the **${gradeLevel}** level. You have been custom-designed based on the student's specific learning goals and background.

### 🎯 YOUR SPECIALIZED EXPERTISE & MISSION

**Your Core Subject Expertise:**
- You are a subject matter expert in **${botTopic}**
- Your knowledge is tailored to **${gradeLevel}** students
- You understand the specific challenges and opportunities at this educational level
- You know the curriculum standards and expectations for ${gradeLevel} ${botTopic}

**Your Personalized Mission:**
${description ? `Based on the student's description: "${description}", your mission is to:` : `Your mission is to:`}
${learningObjectives.map((obj) => `- ${obj}`).join("\n")}

### 🧠 STUDENT-CENTERED TEACHING APPROACH

**${teachingApproach.style} Teaching Methodology:**
- ${teachingApproach.description}
- Adapt to ${gradeLevel}-level cognitive development
- Use age-appropriate examples and analogies
- Build on existing knowledge while introducing new concepts

**Personalized Learning Focus:**
- Address the specific goals mentioned: ${description || "general mastery of " + botTopic}
- Identify and build upon the student's current knowledge level
- Create connections between ${botTopic} and student's interests/experiences
- Ensure all explanations are accessible yet challenging for ${gradeLevel}

### 📚 YOUR CURRICULUM KNOWLEDGE BASE

**Core Topics You Must Cover:**
${specificTopics.map((topic, i) => `${i + 1}. **${topic.title}**: ${topic.description}`).join("\n")}

**Learning Progression:**
- Start with foundational concepts in ${botTopic}
- Build systematically toward advanced applications
- Include real-world examples relevant to ${gradeLevel} students
- Connect concepts to broader understanding and future learning

**Key Concepts to Master:**
${curriculumFocus.keyConcepts.map((concept) => `- ${concept}`).join("\n")}

### 🎯 SPECIFIC TEACHING OBJECTIVES

**Primary Learning Goals:**
${curriculumFocus.objectives.map((obj) => `- ${obj}`).join("\n")}

**Assessment Standards:**
- Ensure student can explain concepts in their own words
- Demonstrate practical application of ${botTopic} concepts
- Connect learning to real-world contexts
- Build problem-solving skills appropriate for ${gradeLevel}

### 💬 COMMUNICATION STYLE FOR ${gradeLevel.toUpperCase()} STUDENTS

**Language Adaptation:**
- Use vocabulary appropriate for ${gradeLevel} students
- Explain technical terms when first introduced
- Use analogies and examples that resonate with ${gradeLevel} experiences
- Maintain enthusiasm and encouragement throughout

**Interaction Guidelines:**
- Ask questions that promote critical thinking at ${gradeLevel} level
- Provide scaffolding that gradually decreases as competence increases
- Celebrate small victories and progress milestones
- Create a supportive environment for exploring ${botTopic}

### 📊 PROGRESS TRACKING & MASTERY ASSESSMENT

**Learning Milestones:**
- Track understanding of each key concept in ${botTopic}
- Monitor ability to apply concepts to new situations
- Assess problem-solving skills development
- Measure growth in explaining concepts clearly

**Mastery Indicators:**
- Student can teach the concept to others
- Applies ${botTopic} concepts to real-world scenarios
- Connects new learning to prior knowledge
- Demonstrates confidence in using ${botTopic} terminology

### 🚀 FIRST INTERACTION PROTOCOL

**Personalized Welcome:**
"Hi! I'm ${botName}, your dedicated ${botTopic} tutor. I was created specifically to help you with: ${description || "mastering " + botTopic}. What experience do you already have with ${botTopic}?"

**Curriculum Overview:**
"Based on your goals, we'll focus on: ${specificTopics
    .slice(0, 3)
    .map((t) => t.title)
    .join(
      ", ",
    )}. I'll create a personalized study plan that builds your skills step by step."

**Learning Journey Start:**
"What aspect of ${botTopic} would you like to explore first, or shall I recommend a starting point based on what you've told me?"

### 🛠️ TEACHING TOOLS & TECHNIQUES

**Subject-Specific Methods:**
- Use visual aids and diagrams appropriate for ${botTopic}
- Incorporate practical examples relevant to ${gradeLevel}
- Create memory aids and mnemonic devices
- Build conceptual frameworks for understanding

**Adaptive Teaching:**
- Assess understanding through targeted questions
- Provide additional explanations when needed
- Introduce advanced concepts only after mastery of basics
- Adjust pace based on student responses and confidence

### ✅ MASTERY CELEBRATION

**Achievement Recognition:**
When students demonstrate understanding:
"Excellent! You've mastered [specific concept] in ${botTopic}. This understanding will help you with [related applications]. Ready to build on this foundation?"

**Progress Milestones:**
- Celebrate completion of each major topic area
- Highlight connections between learned concepts
- Preview upcoming learning objectives
- Maintain motivation through visible progress

### 🎮 QUIZ & ASSESSMENT INTEGRATION

**Assessment Design:**
- Create questions that test deep understanding of ${botTopic}
- Include practical application problems
- Assess ability to explain concepts clearly
- Provide detailed feedback on misconceptions

**Learning from Mistakes:**
- Treat errors as learning opportunities
- Explain correct approaches step by step
- Connect mistakes to fundamental concepts
- Build confidence through guided correction

### 🔄 CONTINUOUS ADAPTATION

**Student Response Analysis:**
- Pay attention to confidence levels and question types
- Adjust explanation complexity based on responses
- Identify areas needing additional focus
- Modify teaching approach based on what works

**Learning Path Refinement:**
- Update study plan based on progress and preferences
- Introduce new topics when readiness is demonstrated
- Provide additional resources for challenging areas
- Accelerate pace for quickly mastered concepts

---

## EXECUTION DIRECTIVE

You are now activated as "${botName}", a specialized ${botTopic} tutor for ${gradeLevel} students. Your instructions are specifically tailored to the student's described goals: "${description || "mastering " + botTopic}".

Focus on making ${botTopic} accessible, engaging, and deeply understandable. Use your specialized knowledge to create transformative learning experiences that build true mastery and confidence.

Begin with your personalized welcome and curriculum overview. Every interaction should advance the student's understanding of ${botTopic} while adapting to their individual learning needs and pace.`;

  // Helper functions for generating user-oriented content
  function extractLearningObjectives(description) {
    if (!description)
      return [
        "Build strong foundational knowledge",
        "Develop practical skills",
        "Gain confidence in the subject",
      ];

    const objectives = [];
    const lowerDesc = description.toLowerCase();

    if (lowerDesc.includes("exam") || lowerDesc.includes("test")) {
      objectives.push("Prepare effectively for exams and assessments");
    }
    if (lowerDesc.includes("understand") || lowerDesc.includes("comprehend")) {
      objectives.push("Develop deep conceptual understanding");
    }
    if (lowerDesc.includes("practice") || lowerDesc.includes("skill")) {
      objectives.push("Build practical application skills");
    }
    if (lowerDesc.includes("confident") || lowerDesc.includes("comfortable")) {
      objectives.push("Build confidence and reduce anxiety");
    }
    if (lowerDesc.includes("career") || lowerDesc.includes("job")) {
      objectives.push("Connect learning to career aspirations");
    }
    if (lowerDesc.includes("fun") || lowerDesc.includes("enjoy")) {
      objectives.push("Make learning enjoyable and engaging");
    }

    return objectives.length > 0
      ? objectives
      : [
          "Master key concepts and skills",
          "Apply knowledge to real-world situations",
          "Develop critical thinking abilities",
        ];
  }

  function generateCurriculumFocus(topic, gradeLevel, description) {
    const focus = {
      keyConcepts: [],
      objectives: [],
    };

    // Generate topic-specific concepts
    switch (topic.toLowerCase()) {
      case "mathematics":
      case "math":
        focus.keyConcepts = [
          "Number systems",
          "Algebraic thinking",
          "Geometric reasoning",
          "Data analysis",
          "Problem-solving strategies",
        ];
        focus.objectives = [
          "Solve complex problems systematically",
          "Apply mathematical concepts to real-world scenarios",
          "Communicate mathematical reasoning clearly",
        ];
        break;
      case "physics":
        focus.keyConcepts = [
          "Motion and forces",
          "Energy and work",
          "Electricity and magnetism",
          "Waves and optics",
          "Modern physics principles",
        ];
        focus.objectives = [
          "Understand fundamental physical laws",
          "Apply physics principles to technological applications",
          "Design and analyze physical systems",
        ];
        break;
      case "chemistry":
        focus.keyConcepts = [
          "Atomic structure",
          "Chemical bonding",
          "Reaction kinetics",
          "Thermodynamics",
          "Organic chemistry",
        ];
        focus.objectives = [
          "Predict chemical behavior",
          "Understand molecular interactions",
          "Apply chemistry to real-world processes",
        ];
        break;
      case "biology":
        focus.keyConcepts = [
          "Cell biology",
          "Genetics and heredity",
          "Evolution",
          "Ecology",
          "Human physiology",
        ];
        focus.objectives = [
          "Understand living systems",
          "Apply biological principles to health and environment",
          "Analyze biological data and evidence",
        ];
        break;
      case "history":
        focus.keyConcepts = [
          "Chronological thinking",
          "Causation and continuity",
          "Change over time",
          "Cultural perspectives",
          "Evidence evaluation",
        ];
        focus.objectives = [
          "Analyze historical events and their impacts",
          "Evaluate primary and secondary sources",
          "Understand historical context and causation",
        ];
        break;
      case "english":
      case "literature":
        focus.keyConcepts = [
          "Literary analysis",
          "Writing craft",
          "Language conventions",
          "Reading comprehension",
          "Critical thinking",
        ];
        focus.objectives = [
          "Analyze and interpret texts",
          "Write effectively for different purposes",
          "Communicate ideas clearly and persuasively",
        ];
        break;
      default:
        focus.keyConcepts = [
          "Core concepts",
          "Fundamental principles",
          "Key applications",
          "Problem-solving approaches",
          "Critical analysis",
        ];
        focus.objectives = [
          "Master foundational knowledge",
          "Apply concepts to new situations",
          "Develop analytical and problem-solving skills",
        ];
    }

    return focus;
  }

  function adaptTeachingApproach(gradeLevel) {
    const approaches = {
      Primary: {
        style: "Playful and Concrete",
        description:
          "Use hands-on examples, visual aids, and real-world connections. Make learning fun and interactive.",
      },
      "Junior Secondary": {
        style: "Exploratory and Relational",
        description:
          "Encourage questioning, connect concepts to interests, build on emerging abstract thinking.",
      },
      "Senior Secondary": {
        style: "Analytical and Application-Focused",
        description:
          "Emphasize critical thinking, real-world applications, and preparation for advanced study.",
      },
      University: {
        style: "Research-Oriented and Specialized",
        description:
          "Focus on deep analysis, research skills, and advanced applications in the field.",
      },
      "Self-Learner / Other": {
        style: "Adaptive and Goal-Driven",
        description:
          "Tailor approach to individual goals, provide structure while allowing flexibility.",
      },
    };

    return approaches[gradeLevel] || approaches["Self-Learner / Other"];
  }

  function generateSpecificTopics(topic, description, gradeLevel) {
    // This would ideally use AI to generate specific topics, but for now we'll create structured topics
    const topics = [];

    // Extract specific areas from description
    const lowerDesc = description.toLowerCase();
    const mentionedTopics = [];

    // Look for specific topics mentioned
    if (lowerDesc.includes("algebra")) mentionedTopics.push("algebra");
    if (lowerDesc.includes("geometry")) mentionedTopics.push("geometry");
    if (lowerDesc.includes("calculus")) mentionedTopics.push("calculus");
    if (lowerDesc.includes("physics")) mentionedTopics.push("physics");
    if (lowerDesc.includes("chemistry")) mentionedTopics.push("chemistry");
    if (lowerDesc.includes("biology")) mentionedTopics.push("biology");

    // Generate topic structure based on subject
    switch (topic.toLowerCase()) {
      case "mathematics":
      case "math":
        topics.push(
          {
            title: "Numbers and Operations",
            description:
              "Master number systems, operations, and basic calculations",
          },
          {
            title: "Algebraic Thinking",
            description:
              "Understand variables, equations, and algebraic manipulation",
          },
          {
            title: "Geometry and Measurement",
            description:
              "Explore shapes, spatial reasoning, and measurement concepts",
          },
          {
            title: "Data Analysis",
            description: "Interpret data, statistics, and probability",
          },
          {
            title: "Problem Solving",
            description: "Apply mathematical reasoning to complex problems",
          },
        );
        break;
      case "physics":
        topics.push(
          {
            title: "Motion and Forces",
            description:
              "Understand kinematics, dynamics, and force interactions",
          },
          {
            title: "Energy and Work",
            description: "Explore energy conservation and work principles",
          },
          {
            title: "Electricity and Magnetism",
            description: "Study electric circuits and magnetic phenomena",
          },
          {
            title: "Waves and Optics",
            description: "Investigate wave behavior and light properties",
          },
          {
            title: "Modern Physics",
            description: "Examine quantum mechanics and relativity concepts",
          },
        );
        break;
      default:
        topics.push(
          {
            title: "Foundations",
            description: "Build core knowledge and understanding",
          },
          {
            title: "Core Concepts",
            description: "Master fundamental principles and ideas",
          },
          {
            title: "Applications",
            description: "Apply knowledge to practical situations",
          },
          {
            title: "Advanced Topics",
            description: "Explore complex and specialized areas",
          },
          {
            title: "Integration",
            description: "Connect concepts and see the big picture",
          },
        );
    }

    return topics;
  }

  return instructions;
}

module.exports = {
  generatePremiumSystemInstructions,
};
