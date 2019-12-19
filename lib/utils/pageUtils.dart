import 'package:dd_player/utils/series.dart';

class PageUtils{
  int currentPage;
  int allCount;
  int pageSize;

  // 1 -> 第1-10集
  Map<int, String> pageDescMap = {};

  // 所有剧集
  List<Series> datas = [];

  // 分页剧集
  Map<int, List<Series>> pageDatas={};

  PageUtils({
    this.currentPage, 
    this.allCount, 
    this.pageSize, 
    this.pageDescMap,
    this.datas
  });
  
  void init(){
    allCount = datas.length;
    currentPage = 1;
    pageDescMap = {};
    pageDatas = {};

    while(((currentPage - 1) * pageSize + pageSize) <= allCount) {
      String pageStr = "第"+((currentPage-1)*pageSize+1).toString()+"-"+((currentPage-1)*pageSize+pageSize).toString()+"集";
      pageDescMap.putIfAbsent(currentPage, ()=>pageStr);
      pageDatas.putIfAbsent(currentPage, ()=>datas.sublist((currentPage-1)*pageSize, (currentPage-1)*pageSize+pageSize));

      currentPage ++;
    }

    if(((currentPage-1)*pageSize+1) < allCount) {
      String pageStr = "第"+((currentPage-1)*pageSize+1).toString()+"-"+allCount.toString()+"集";
      pageDescMap.putIfAbsent(currentPage, ()=>pageStr);
      pageDatas.putIfAbsent(currentPage, ()=> datas.sublist((currentPage-1)*pageSize, allCount));
    }
    if(((currentPage-1)*pageSize+1) == allCount) {
      String pageStr = "第"+allCount.toString()+"集";
      pageDescMap.putIfAbsent(currentPage, ()=>pageStr);
      pageDatas.putIfAbsent(currentPage, ()=>datas.sublist(allCount-1, allCount));
    }
  }
}