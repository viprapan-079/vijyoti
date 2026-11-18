import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'astro.dart';
import 'cities.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeEphemeris();
    runApp(const JyotishyaApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Padding(
      padding: const EdgeInsets.all(20), child: Text('Ephemeris initialization failed: $e'))))));
  }
}

class JyotishyaApp extends StatelessWidget {
  const JyotishyaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jyotishya Kundali', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF965424)), useMaterial3: true),
    home: const KundaliHome(),
  );
}

class KundaliHome extends StatefulWidget {
  const KundaliHome({super.key});
  @override
  State<KundaliHome> createState() => _KundaliHomeState();
}

class _KundaliHomeState extends State<KundaliHome> {
  final name = TextEditingController();
  final otherPlace = TextEditingController();
  final lat = TextEditingController(text: '12.9141');
  final lon = TextEditingController(text: '74.8560');
  IndianCity? city = indianCities.firstWhere((c) => c.name.startsWith('Mangaluru'));
  DateTime date = DateTime(2000, 1, 1);
  TimeOfDay time = const TimeOfDay(hour: 12, minute: 0);
  Horoscope? chart;
  DateTime? chartDate;
  String? chartPlace;
  String? error;
  bool todayMode = false;
  int page = 0;
  List<Map<String,dynamic>> saved = [];

  @override
  void initState() { super.initState(); _loadSaved(); }
  @override
  void dispose() {
    for (final c in [name, otherPlace, lat, lon]) { c.dispose(); }
    super.dispose();
  }
  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('birth_records_v2');
    if (raw == null) return;
    try { final decoded = (jsonDecode(raw) as List).cast<Map<String,dynamic>>();
      if (mounted) setState(() => saved = decoded); } catch (_) { /* ignore invalid storage */ }
  }
  Future<void> _saveRecord() async {
    if (chart == null || todayMode) return;
    final record = <String,dynamic>{'name':name.text.trim(), 'date':date.toIso8601String(),
      'hour':time.hour,'minute':time.minute,'city':city?.name ?? '',
      'otherPlace':otherPlace.text.trim(),'lat':lat.text,'lon':lon.text};
    setState(() => saved.insert(0, record));
    final p = await SharedPreferences.getInstance();
    await p.setString('birth_records_v2', jsonEncode(saved));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on this phone (offline).')));
  }
  Future<void> _deleteRecord(int i) async {
    setState(() => saved.removeAt(i));
    final p = await SharedPreferences.getInstance();
    await p.setString('birth_records_v2', jsonEncode(saved));
  }
  void _restoreRecord(Map<String,dynamic> r) {
    name.text = r['name']?.toString() ?? '';
    date = DateTime.parse(r['date'] as String);
    time = TimeOfDay(hour: r['hour'] as int, minute: r['minute'] as int);
    final place = (r['city'] ?? '').toString();
    city = place.isEmpty ? null : indianCities.where((c) => c.name == place).firstOrNull;
    otherPlace.text = (r['otherPlace'] ?? '').toString();
    lat.text = r['lat'].toString(); lon.text = r['lon'].toString();
    todayMode = false;
    _calculate();
  }
  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: date,
      firstDate: DateTime(1800), lastDate: DateTime(2200));
    if (d != null) setState(() => date = d);
  }
  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: time);
    if (t != null) setState(() => time = t);
  }
  void _selectCity(IndianCity? c) {
    setState(() {city = c;
      if (c != null) {lat.text = c.lat.toString();lon.text = c.lon.toString();}
    });
  }
  void _calculate() {
    try {
      final latitude = double.parse(lat.text.trim());
      final longitude = double.parse(lon.text.trim());
      final local = DateTime(date.year,date.month,date.day,time.hour,time.minute);
      final result = calculateHoroscope(localBirth: local, timezoneHours: 5.5,
        latitude: latitude, longitude: longitude);
      setState(() {chart = result; chartDate = local;
        chartPlace = city?.name ?? otherPlace.text.trim(); error = null; page = 0;});
    } catch (e) {setState(() {chart=null; error='Unable to calculate: $e';});}
  }
  void _openToday() {
    final now = DateTime.now();
    setState(() {todayMode = true; date=DateTime(now.year,now.month,now.day);
      time=TimeOfDay(hour:now.hour,minute:now.minute);});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ॐ Jyotishya Kundali'), actions: [
      IconButton(tooltip:'Saved charts', onPressed:_showSaved, icon:const Icon(Icons.bookmarks_outlined))]),
    body: ListView(padding:const EdgeInsets.all(14), children:[
      SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Janma Kundali')),
        ButtonSegment(value:true,label:Text("Today's Kundali"))],
        selected:{todayMode}, onSelectionChanged:(v) {if (v.first) _openToday(); else setState(()=>todayMode=false);}),
      const SizedBox(height:14),
      if (!todayMode) TextField(controller:name, decoration:const InputDecoration(
        border:OutlineInputBorder(),labelText:'Person name')),
      const SizedBox(height:12),
      Wrap(spacing:8, runSpacing:8, children:[
        OutlinedButton.icon(onPressed:_pickDate,icon:const Icon(Icons.calendar_month),
          label:Text('${date.day}/${date.month}/${date.year}')),
        OutlinedButton.icon(onPressed:_pickTime,icon:const Icon(Icons.access_time),
          label:Text(time.format(context))),
      ]),
      const SizedBox(height:10),
      DropdownButtonFormField<IndianCity>(value:city, isExpanded:true,
        decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Birthplace / chart location (India)'),
        items:[...indianCities.map((c)=>DropdownMenuItem(value:c,child:Text(c.name))),
          const DropdownMenuItem(value:null,child:Text('Other place (manual coordinates)'))],
        onChanged:_selectCity),
      if (city == null) ...[
        const SizedBox(height:10),
        TextField(controller:otherPlace, decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Place name')),
      ],
      const SizedBox(height:10),
      Row(children:[Expanded(child:TextField(controller:lat, keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),
        decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Latitude'))),
        const SizedBox(width:8), Expanded(child:TextField(controller:lon,
        keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),
        decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Longitude')))]),
      const SizedBox(height:6),
      const Text('Time zone: India Standard Time (UTC +05:30). For locations outside India, conversion must be added.',
        style:TextStyle(fontSize:12)),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:_calculate,icon:const Icon(Icons.auto_awesome),
        label:Text(todayMode?'Calculate chart for selected day':'Calculate Janma Kundali')),
      if (error != null) Padding(padding:const EdgeInsets.all(8), child:Text(error!,style:const TextStyle(color:Colors.red))),
      if (chart != null) ...[
        const SizedBox(height:12),
        if (!todayMode) OutlinedButton.icon(onPressed:_saveRecord,icon:const Icon(Icons.save_outlined),label:const Text('Save birth record offline')),
        const SizedBox(height:12),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(todayMode?2:4,(i)=>
          Padding(padding:const EdgeInsets.only(right:5),child:ChoiceChip(label:Text(todayMode?
            ['Day details','Day Rashi'][i]:['1 Details','2 Dasha','3 Navamsha','4 Janma'][i]),
            selected:page==i,onSelected:(_)=>setState(()=>page=i))))),
        const SizedBox(height:14),
        if (todayMode) (page==0?_details():_chart(1,'Rashi Kundali for selected day'))
        else switch(page) {0=>_details(),1=>_dasha(),2=>_chart(9,'Navamsha Kundali (D9)'),_=>_chart(1,'Janma Kundali (D1)')},
        const SizedBox(height:10),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          OutlinedButton(onPressed:page>0?()=>setState(()=>page--):null,child:const Text('Previous')),
          Text('Page ${page+1} of ${todayMode?2:4}'),
          FilledButton(onPressed:page<(todayMode?1:3)?()=>setState(()=>page++):null,child:const Text('Next')),
        ]),
        const SizedBox(height:12),
        const Text('Testing notice: Dasha-year convention is 365.2425 days; compare results with a trusted reference before professional use.',style:TextStyle(fontSize:12)),
      ],
    ]),
  );
  Widget _details() {
    final moon = chart!.planets.firstWhere((p)=>p.label=='Moon');
    final lagna = chart!.planets.firstWhere((p)=>p.label=='Lagna');
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(todayMode?'Selected Day Details':'Page 1: Janma Details',style:Theme.of(context).textTheme.titleLarge),
      if (!todayMode) ListTile(title:const Text('Name'),subtitle:Text(name.text.trim().isEmpty?'Not entered':name.text.trim())),
      ListTile(title:const Text('Date and time'),subtitle:Text('${fmt(chartDate!)}  ${time.format(context)} IST')),
      ListTile(title:const Text('Place'),subtitle:Text(chartPlace??'')),
      ListTile(title:const Text('Rashi'),subtitle:Text(rashis[moon.d1])),
      ListTile(title:const Text('Nakshatra / Pada'),subtitle:Text('${nakshatras[chart!.nakshatraIndex]} / Pada ${chart!.pada}')),
      ListTile(title:const Text('Lagna'),subtitle:Text(rashis[lagna.d1])),
      ListTile(title:const Text('Lahiri Ayanamsha'),subtitle:Text('${chart!.ayanamsa.toStringAsFixed(5)}°')),
      const Text('Planetary positions',style:TextStyle(fontWeight:FontWeight.bold)),
      ...chart!.planets.map((p)=>ListTile(dense:true,title:Text(p.label),trailing:Text(p.formatted))),
    ]);
  }
  Widget _dasha()=>Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
    Text('Page 2: Mahadasha • Bhukti • Antara',style:Theme.of(context).textTheme.titleLarge),
    const Text('Tap a Mahadasha and Bhukti to expand the dates.'),
    ...chart!.periods.map((p)=>ExpansionTile(
      title:Text('${p.lord} Mahadasha'),subtitle:Text('${fmt(p.startUtc.toLocal())} – ${fmt(p.endUtc.toLocal())}'),
      children:p.subPeriods.map((b)=>ExpansionTile(
        title:Text('${p.lord} / ${b.lord} Bhukti'),
        subtitle:Text('${fmt(b.startUtc.toLocal())} – ${fmt(b.endUtc.toLocal())}'),
        children:b.subPeriods.map((a)=>ListTile(dense:true,
          title:Text('${a.lord} Antara'),subtitle:Text('${fmt(a.startUtc.toLocal())} – ${fmt(a.endUtc.toLocal())}'))).toList(),
      )).toList(),
    )),
  ]);
  Widget _chart(int division,String title)=>Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
    Text('Page ${division==9?3:4}: $title',style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:12),SouthChart(placements:chart!.planets,divisional:division),
    const SizedBox(height:12),
    ...chart!.planets.map((p)=>ListTile(dense:true,title:Text(p.label),
      trailing:Text(rashis[division==9?p.d9:p.d1]))),
  ]);
  void _showSaved() {
    showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(sheetContext)=>SafeArea(
      child:Padding(padding:const EdgeInsets.all(14),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('Saved birth records',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        SizedBox(height:350,child:saved.isEmpty?const Center(child:Text('No saved Kundalis yet')):
          ListView.builder(itemCount:saved.length,itemBuilder:(context,i)=>ListTile(
            title:Text(saved[i]['name']?.toString().isNotEmpty==true?saved[i]['name'].toString():'Unnamed person'),
            subtitle:Text('${saved[i]['city']?.toString().isNotEmpty==true?saved[i]['city']:saved[i]['otherPlace']} • ${saved[i]['date'].toString().split('T').first}'),
            trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:(){_deleteRecord(i);Navigator.pop(sheetContext);_showSaved();}),
            onTap:(){Navigator.pop(sheetContext);_restoreRecord(saved[i]);},
          ))),
      ]))));
  }
}

String fmt(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

class SouthChart extends StatelessWidget {
  final List<Placement> placements;
  final int divisional;
  const SouthChart({super.key,required this.placements,required this.divisional});
  static const cells = [11,0,1,2,10,-1,-1,3,9,-1,-1,4,8,7,6,5];
  @override
  Widget build(BuildContext context) {
    final bySign = <int,List<String>>{for(var i=0;i<12;i++)i:[]};
    for(final p in placements) {
      final sign=divisional==1?p.d1:p.d9;
      bySign[sign]!.add(p.label=='Lagna'?'Asc':p.label.substring(0,p.label.length<2?p.label.length:2));
    }
    return AspectRatio(aspectRatio:1,child:GridView.builder(
      physics:const NeverScrollableScrollPhysics(),
      gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4),
      itemCount:16,itemBuilder:(context,i){
        final sign=cells[i];
        return Container(decoration:BoxDecoration(border:Border.all(color:const Color(0xFF986E45),width:.7),color:const Color(0xFFFFF9EA)),
          child:sign<0?null:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Text(rashis[sign],style:const TextStyle(fontSize:10,color:Colors.brown)),
            Text(bySign[sign]!.join(' '),textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
          ]));
      },
    ));
  }
}
