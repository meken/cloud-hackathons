# Easy Ads: From Concept to Creation with GenMedia

## Introduction

Welcome to the coach's guide for the *Easy Ads: From Concept to Creation with GenMedia* gHack. Here you will find links to specific guidance for coaches for each of the challenges.

> [!NOTE]  
> If you are a gHacks participant, this is the answer guide. Don't cheat yourself by looking at this guide during the hack!

## Coach's Guides

## Challenges

- Challenge 1: From Product to Narrative  
- Challenge 2: The Visual Blueprint  
- Challenge 3: From Stills to Motion  
- Challenge 4: The Assembly  
- Challenge 5: Giving It a Voice  
- Challenge 6: The Soundtrack  

## Challenge 1: From Product to Narrative

### Notes & Guidance

If the participants are using Vertex AI Studio for generating the story, they should turn on auto-save. This way they can keep track of their progress and easily hand over the generated descriptions to the next driver.

> [!NOTE]  
> As mentioned in the instructions using Gemini is fair game, but using the first best response might lead to generic outputs, so adding a bit of creativity, or a few more iterations, would make the end results better.

It is helpful to have generic system instructions when using Gemini, although there would be great variety, something like that captures what we expect (the purpose and the subject):

```text
We're creating an ad for a product called The Cymbal Pod which is a single person, urban transport vehicle that hovers silently and moves quietly through the world.
```

Although it's hard to assess the quality of the deliverables, these should be consistent, coherent, on-brand and brief.

We're expecting *at least* three scenes, but it makes sense to have more (and shorter) scenes. Veo will struggle if there's too much happening in a single scene. The snippet below is from *Veo Prompting Best Practices*:

> Attempting to prompt "A knight battles a dragon, then flies on its back to a castle, then attends a feast" in a single prompt for an 8-second clip will likely result in a muddled or incomplete depiction of one small part, or a very rushed and incoherent sequence. Instead, generate each distinct part as a separate clip if needed

#### Pro Tips for the Students

- Take **5 mins** with your team discussing what the brand guidelines, product and protagonist should be like. Be creative! Don't waste time here.
- See the example below and use Gemini to help you write.  
- Focus on your story and keep in mind that you have 20-30 seconds to tell that story. Each scene is about 8 seconds.  
- Don't try to squeeze too many different things in a single scene. Keep it simple.  
- Parallelize your work.
  - One person can work on the POD/vehicle/Product design  
  - One person on Styling - think about your favourite movie and their color pallets. [Some ideas here](https://digitalsynopsis.com/design/cinema-palettes-famous-movie-colors/#google_vignette)  
  - One person on the Protagonist  
  - Rest work on a storyline/narrative.

## Challenge 2: The Visual Blueprint

### Notes & Guidance

The idea is that the participants should use the descriptions from Challenge 1, and use either Gemini or *Help me write* capabilities with Vertex AI Media Studio to generate the required prompts. Nano Banana can be used to create the original images as well as to generate the different angles.

> [!IMPORTANT]  
> Participants should try to stay away from *Imagen* family of models, these are not well suited for this task. *Gemini Native Image* (aka: *Nano Banana*) is the recommended model.

For the storyboard scene generation again Nano Banana would be the best fit. They can start uploading the relevant protagonist and product pictures together with the text of the their storyboard scene (maybe optimized through Gemini or *Help me write* capabilities) to generate the images.

> [!WARNING]  
> At the time of this writing Nano Banana in Vertex AI Media Studio has a limit of 10MB, so if there are too many images inserted in a single conversation, things will fail. Also there are limits to how many images can be included in a single prompt (3 for Nano Banana at the moment), if the participants go beyond that limit, Nano Banana will silently ignore those. Participants should use multiple conversations and/or fewer images.

#### Pro Tips for the Students

- The more details provided by the output of the previous challenge, the more consistent your images will be.
- Avoid too many things at once. Keep the scene clean. Focus on a good storyline. It can be funny, it can be emotional.  
- Google Models take IP and Safety very seriously. Do not use any known persons, products likeness or names. Safety filter will trigger if Gemini detects such references in the prompt.  
- Have a distinct tagline and logo.

## Challenge 3: From Stills to Motion

### Notes & Guidance

The storyboard images created in the previous challenge should be used as a *Reference* to generate the video clips. If the participants gloss over this, they will struggle with consistency. Similarly, just like the previous challenge, **DO NOT** let them struggle for too long.

There's a plethora of different options here, participants can use the story board imags as *Reference*s, or generate start and end frames based on the story board and use those for the newer *Veo* models.

#### Pro Tips for the Students

- In the interest of time and so that everyone gets to play, parallelize this task across your team.
- Video generation is time-intensive. To optimize efficiency, we recommend that **two or three team members simultaneously generate distinct video sets**. Afterwards, compare and select the most effective clips, or regenerate as necessary. Do not delay progress.
- For enhanced consistency, consider **utilizing a screenshot of the final frame** from Video 1 as the initiating frame for Video 2.
- Upload **3-5** images and detailed descriptions.
- Can't emphasize enough to go through this guide [Veo on Vertex AI video generation prompt guide](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/video/video-gen-prompt-guide). This separates a great shot from a good shot.
- Google Models take IP and Safety very seriously. Do not use any known persons, products, films, references, likeness or names. Safety filter will trigger if Gemini detects such references in the prompt.
- If you see your character develop discrepancies between scenes, like their look changes, go back to the previous challenge and develop better images.
- Also if certain actions are not consistent (opening doors differently), include reference images for those.

## Challenge 4: The Assembly

### Notes & Guidance

#### Video Editor

In the rest of this gHack's challenges, you will be piecing together your final ad video. Unless you prefer your own editing tools (Adobe Premiere Pro, Final Cut Pro, DaVinci Resolve, etc), we strongly recommend using Google Vids.

Google Vids is a web-based video creation app designed to make producing professional videos as simple as creating a slide deck without any prior video editing experience. It is available on any Google Workspace account and also on personal gmail accounts if necessary.

#### Pro Tips for the Students

- Don't worry about the sound at this step. Just focus on the complete Video. You will add a voiceover in the next step  
- You could use Gemini for generating text as well, but in case you're not getting what you want, you can just use text elements within your video editor.

## Challenge 5: Giving It a Voice

### Notes & Guidance

You'll have the choice to use Google's Chirp 3 HD model or Gemini itself to create the voice-overs. The difference between these two lies in the source of vocal identity and style. Chirp functions as an advanced text-to-speech engine, requiring a pre-existing voice, either from its library or a custom clone, to articulate the provided text with high fidelity; any stylistic nuance is primarily achieved through manipulating the text itself with punctuation and pacing adjustments. In contrast, Gemini operates as a true generative voice model, creating the vocal characteristics and delivery style from scratch based on natural language prompts. This allows a user to conjure a voice by describing it (e.g., "a deep, soothing voice") and directing its emotional tone (e.g., "speak with excitement"), offering a layer of creative control and on-the-fly vocal design that Chirp, in this context, does not.

#### Pro Tips for the Students

- This is the final touch of your video. A good narrative is what you need.
- You can sample voices and choose the right voice from the samples [here](https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd).  
- If you have already established if it's a male or female voice the choice is easier!
- Finally, add these audio tracks in the proper places in your video sequence timeline. You can use Vids to insert the audio. You can change the speed of the audio in both Vids and in Chirp.

## Challenge 6: The Soundtrack

### Notes & Guidance

Including instrument information in the prompt can be helpful.
